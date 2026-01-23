import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_gridnavia_basic(dut):
    """Test basic 3x3 grid case with valid solution"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.single_lang_mask.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: 3x3 grid (simplified from problem)
    # Map: 2 2 1
    #      1 1 2
    #      1 1 2
    # Encoded as 64-bit mask (row-major)
    # '1' = exactly one language (bit=1), '2' = >=2 languages (bit=0)
    # Actually, let's use: bit=1 means needs exactly one language
    # Grid cells:
    # Row 0: (0,0)=2(0), (0,1)=2(0), (0,2)=1(1)
    # Row 1: (1,0)=1(1), (1,1)=1(1), (1,2)=2(0)
    # Row 2: (2,0)=1(1), (2,1)=1(1), (2,2)=2(0)
    
    # 3x3 grid embedded in 8x8
    # Cells (0,0) to (2,2) are active
    # single_lang_mask: set bits where value is '1'
    # (0,2)=1 -> index 2, (1,0)=1 -> index 8, (1,1)=1 -> index 9
    # (2,0)=1 -> index 16, (2,1)=1 -> index 17
    mask = (1 << 2) | (1 << 8) | (1 << 9) | (1 << 16) | (1 << 17)
    dut.single_lang_mask.value = mask
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 1024 cycles)
    cycles = 0
    while not dut.done.value and cycles < 1100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 1100:
        raise TestFailure("Computation did not complete within 1100 cycles")
    
    if not dut.valid.value:
        raise TestFailure("Solution was marked invalid")
    
    # Read results
    lang_a = int(dut.lang_a_mask.value)
    lang_b = int(dut.lang_b_mask.value)
    lang_c = int(dut.lang_c_mask.value)
    
    # Verify all cells in 3x3 region are covered
    region_mask = 0
    for r in range(3):
        for c in range(3):
            idx = r * 8 + c
            region_mask |= (1 << idx)
    
    combined = lang_a | lang_b | lang_c
    if (combined & region_mask) != region_mask:
        raise TestFailure(f"Not all cells covered. Missing: {bin((~combined) & region_mask)}")
    
    # Verify no cell is assigned to zero languages in active region
    active_cells = region_mask
    covered = combined & active_cells
    if covered != active_cells:
        raise TestFailure("Some active cells have no language assigned")
    
    # Verify '1' cells are in exactly one language
    ones_in_region = mask & region_mask
    for i in range(64):
        if (ones_in_region >> i) & 1:
            count = ((lang_a >> i) & 1) + ((lang_b >> i) & 1) + ((lang_c >> i) & 1)
            if count != 1:
                raise TestFailure(f"Cell {i} marked '1' but assigned to {count} languages")
    
    # Basic connectivity check: each region should have at least 1 cell
    if lang_a == 0 or lang_b == 0 or lang_c == 0:
        raise TestFailure("One language region is empty")
    
    dut._log.info(f"Test passed! A={lang_a:064b}, B={lang_b:064b}, C={lang_c:064b}")

@cocotb.test()
async def test_gridnavia_single_cell(dut):
    """Test 1x1 grid - should be impossible"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.single_lang_mask.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 1x1 grid, cell needs exactly 1 language
    mask = 1 << 0  # Cell (0,0)
    dut.single_lang_mask.value = mask
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 1100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    # Should complete but be invalid (can't satisfy 3 non-empty regions with 1 cell)
    if cycles >= 1100:
        raise TestFailure("Computation did not complete")
    
    if dut.valid.value:
        # Check if it's actually valid (maybe assignment shares the cell?)
        # But constraint says each region must be non-empty
        # So valid should be false
        dut._log.warning("Single cell case returned valid - checking if constraints met")
    
    lang_a = int(dut.lang_a_mask.value)
    lang_b = int(dut.lang_b_mask.value)
    lang_c = int(dut.lang_c_mask.value)
    
    # For valid solution: cell (0,0) marked '1' must be in exactly 1 region
    # AND all 3 regions must be non-empty
    # This is impossible!
    
    # If valid, check constraints
    if dut.valid.value:
        total = lang_a + lang_b + lang_c
        if total != 1:
            raise TestFailure("Single cell case should have exactly 1 total assignment")
        if lang_a == 0 or lang_b == 0 or lang_c == 0:
            # At least one region empty - but valid was high, contradiction
            raise TestFailure("Valid high but empty region exists")
        # If we get here, all regions non-empty and cell assigned once - impossible!
        # So it's wrong
        raise TestFailure("Single cell with 3 non-empty regions is impossible")
    
    dut._log.info("Single cell case correctly handled as impossible")

@cocotb.test()
async def test_gridnavia_all_twos(dut):
    """Test grid where all cells need >=2 languages"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.single_lang_mask.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 2x2 grid, all cells need >=2 languages (mask=0)
    # Cells: (0,0),(0,1),(1,0),(1,1)
    # Set mask to 0 (all bits 0 = all need >=2)
    dut.single_lang_mask.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 1100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 1100:
        raise TestFailure("Computation did not complete")
    
    if not dut.valid.value:
        raise TestFailure("All-2s grid should have valid solution")
    
    lang_a = int(dut.lang_a_mask.value)
    lang_b = int(dut.lang_b_mask.value)
    lang_c = int(dut.lang_c_mask.value)
    
    # Check 2x2 region covered
    region_mask = 0
    for r in range(2):
        for c in range(2):
            idx = r * 8 + c
            region_mask |= (1 << idx)
    
    combined = lang_a | lang_b | lang_c
    if (combined & region_mask) != region_mask:
        raise TestFailure("Not all cells covered")
    
    # All cells need >=2, so each should be in at least 2 regions
    for i in range(64):
        if (region_mask >> i) & 1:
            count = ((lang_a >> i) & 1) + ((lang_b >> i) & 1) + ((lang_c >> i) & 1)
            if count < 2:
                raise TestFailure(f"Cell {i} needs >=2 but assigned to {count}")
    
    if lang_a == 0 or lang_b == 0 or lang_c == 0:
        raise TestFailure("One region is empty")
    
    dut._log.info("All-2s test passed")

@cocotb.test()
async def test_gridnavia_pattern(dut):
    """Test specific 3x4 pattern from problem"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.single_lang_mask.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3x4 grid:
    # Row0: 2 2 1 1
    # Row1: 1 1 1 2
    # Row2: 1 1 1 2
    # '1' cells: (0,2),(0,3),(1,0),(1,1),(1,2),(2,0),(2,1),(2,2)
    # '2' cells: (0,0),(0,1),(1,3),(2,3)
    
    mask = 0
    ones_pos = [(0,2),(0,3),(1,0),(1,1),(1,2),(2,0),(2,1),(2,2)]
    for r, c in ones_pos:
        idx = r * 8 + c
        mask |= (1 << idx)
    
    dut.single_lang_mask.value = mask
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 1100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 1100:
        raise TestFailure("Computation did not complete")
    
    if not dut.valid.value:
        raise TestFailure("Should have solution for this pattern")
    
    lang_a = int(dut.lang_a_mask.value)
    lang_b = int(dut.lang_b_mask.value)
    lang_c = int(dut.lang_c_mask.value)
    
    # Verify 3x4 region
    region_mask = 0
    for r in range(3):
        for c in range(4):
            idx = r * 8 + c
            region_mask |= (1 << idx)
    
    combined = lang_a | lang_b | lang_c
    if (combined & region_mask) != region_mask:
        raise TestFailure("Not all cells covered")
    
    # Check '1' cells have exactly 1 language
    ones_mask = mask & region_mask
    for i in range(64):
        if (ones_mask >> i) & 1:
            count = ((lang_a >> i) & 1) + ((lang_b >> i) & 1) + ((lang_c >> i) & 1)
            if count != 1:
                raise TestFailure(f"Cell {i} marked '1' but has {count} languages")
    
    # Check '2' cells have at least 2 languages
    twos_mask = (~mask) & region_mask
    for i in range(64):
        if (twos_mask >> i) & 1:
            count = ((lang_a >> i) & 1) + ((lang_b >> i) & 1) + ((lang_c >> i) & 1)
            if count < 2:
                raise TestFailure(f"Cell {i} marked '2' but has {count} languages")
    
    dut._log.info("Pattern test passed")
