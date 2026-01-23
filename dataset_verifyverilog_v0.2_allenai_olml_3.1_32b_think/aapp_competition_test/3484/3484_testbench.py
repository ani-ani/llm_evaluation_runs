import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_superdoku_basic(dut):
    """Test basic 4x4 Superdoku with 2 pre-filled rows"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: n=4, k=2
    # Row 0: 1 2 3 4 (00 01 10 11)
    # Row 1: 2 3 4 1 (01 10 11 00)
    
    dut.k.value = 2
    
    # Load row 0
    dut.row_idx.value = 0
    dut.cell_idx.value = 0
    dut.data_in.value = 0  # 1
    await RisingEdge(dut.clk)
    
    dut.cell_idx.value = 1
    dut.data_in.value = 1  # 2
    await RisingEdge(dut.clk)
    
    dut.cell_idx.value = 2
    dut.data_in.value = 2  # 3
    await RisingEdge(dut.clk)
    
    dut.cell_idx.value = 3
    dut.data_in.value = 3  # 4
    await RisingEdge(dut.clk)
    
    # Load row 1
    dut.row_idx.value = 1
    dut.cell_idx.value = 0
    dut.data_in.value = 1  # 2
    await RisingEdge(dut.clk)
    
    dut.cell_idx.value = 1
    dut.data_in.value = 2  # 3
    await RisingEdge(dut.clk)
    
    dut.cell_idx.value = 2
    dut.data_in.value = 3  # 4
    await RisingEdge(dut.clk)
    
    dut.cell_idx.value = 3
    dut.data_in.value = 0  # 1
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 12 cycles)
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check results
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within 15 cycles")
    
    if dut.solvable.value != 1:
        raise TestFailure("Puzzle should be solvable")
    
    if dut.valid.value != 1:
        raise TestFailure("Solution should be valid")
    
    # Expected output:
    # Row 0: 1 2 3 4 (00 01 10 11)
    # Row 1: 2 3 4 1 (01 10 11 00)
    # Row 2: 3 4 1 2 (10 11 00 01) - shift row 0 by 2
    # Row 3: 4 1 2 3 (11 00 01 10) - shift row 0 by 3
    
    # Check row 2
    if dut.grid_out[2][0].value != 2:  # 3
        raise TestFailure(f"Row 2, Col 0: expected 2 (3), got {dut.grid_out[2][0].value}")
    if dut.grid_out[2][1].value != 3:  # 4
        raise TestFailure(f"Row 2, Col 1: expected 3 (4), got {dut.grid_out[2][1].value}")
    if dut.grid_out[2][2].value != 0:  # 1
        raise TestFailure(f"Row 2, Col 2: expected 0 (1), got {dut.grid_out[2][2].value}")
    if dut.grid_out[2][3].value != 1:  # 2
        raise TestFailure(f"Row 2, Col 3: expected 1 (2), got {dut.grid_out[2][3].value}")
    
    # Check row 3
    if dut.grid_out[3][0].value != 3:  # 4
        raise TestFailure(f"Row 3, Col 0: expected 3 (4), got {dut.grid_out[3][0].value}")
    if dut.grid_out[3][1].value != 0:  # 1
        raise TestFailure(f"Row 3, Col 1: expected 0 (1), got {dut.grid_out[3][1].value}")
    if dut.grid_out[3][2].value != 1:  # 2
        raise TestFailure(f"Row 3, Col 2: expected 1 (2), got {dut.grid_out[3][2].value}")
    if dut.grid_out[3][3].value != 2:  # 3
        raise TestFailure(f"Row 3, Col 3: expected 2 (3), got {dut.grid_out[3][3].value}")
    
    print("Test 1 PASSED: 4x4 Superdoku with 2 rows completed")

@cocotb.test()
async def test_superdoku_unsolvable(dut):
    """Test unsolvable case with duplicate values in a row"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: Row 0 has duplicates (1 1 3 4) - invalid
    dut.k.value = 1
    
    dut.row_idx.value = 0
    dut.cell_idx.value = 0
    dut.data_in.value = 0  # 1
    await RisingEdge(dut.clk)
    
    dut.cell_idx.value = 1
    dut.data_in.value = 0  # 1 (duplicate)
    await RisingEdge(dut.clk)
    
    dut.cell_idx.value = 2
    dut.data_in.value = 2  # 3
    await RisingEdge(dut.clk)
    
    dut.cell_idx.value = 3
    dut.data_in.value = 3  # 4
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Should be unsolvable
    if dut.solvable.value != 0:
        raise TestFailure("Should be unsolvable (duplicate in input row)")
    
    print("Test 2 PASSED: Unsolvable case with duplicate detected")

@cocotb.test()
async def test_superdoku_no_prefill(dut):
    """Test with k=0 (no pre-filled rows)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # No rows to load
    dut.k.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Should be solvable (default 1,2,3,4)
    if dut.solvable.value != 1:
        raise TestFailure("Should be solvable with default row")
    
    if dut.valid.value != 1:
        raise TestFailure("Solution should be valid")
    
    # Check that generated grid is valid Latin square
    # Row 0 should be 1,2,3,4 (0,1,2,3)
    if dut.grid_out[0][0].value != 0 or dut.grid_out[0][1].value != 1:
        raise TestFailure("Default row 0 incorrect")
    
    print("Test 3 PASSED: k=0 case with default generation")

@cocotb.test()
async def test_superdoku_full_check(dut):
    """Test column validation for valid solution"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load 2 rows for a valid Latin square pattern
    dut.k.value = 2
    
    # Row 0: 1 2 3 4 (0 1 2 3)
    dut.row_idx.value = 0
    for i, val in enumerate([0, 1, 2, 3]):
        dut.cell_idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    # Row 1: 3 4 1 2 (2 3 0 1)
    dut.row_idx.value = 1
    for i, val in enumerate([2, 3, 0, 1]):
        dut.cell_idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # This should be unsolvable because row 0 and 1 are not cyclic shifts
    # The algorithm will generate rows 2 and 3 as shifts of row 0
    # Row 2: 3 4 1 2 (2 3 0 1) - matches row 1!
    # Row 3: 4 1 2 3 (3 0 1 2)
    # Check columns: Col 0 has 1,3,3,4 - duplicate! So unsolvable
    
    if dut.solvable.value != 0:
        raise TestFailure("Should be unsolvable - columns have duplicates")
    
    print("Test 4 PASSED: Column validation works correctly")

@cocotb.test()
async def test_superdoku_all_rows_given(dut):
    """Test with all 4 rows pre-filled (k=4)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load 4 rows
    dut.k.value = 4
    
    # Row 0: 1 2 3 4 (0 1 2 3)
    dut.row_idx.value = 0
    for i, val in enumerate([0, 1, 2, 3]):
        dut.cell_idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    # Row 1: 2 3 4 1 (1 2 3 0)
    dut.row_idx.value = 1
    for i, val in enumerate([1, 2, 3, 0]):
        dut.cell_idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    # Row 2: 3 4 1 2 (2 3 0 1)
    dut.row_idx.value = 2
    for i, val in enumerate([2, 3, 0, 1]):
        dut.cell_idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    # Row 3: 4 1 2 3 (3 0 1 2)
    dut.row_idx.value = 3
    for i, val in enumerate([3, 0, 1, 2]):
        dut.cell_idx.value = i
        dut.data_in.value = val
        await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Should be solvable
    if dut.solvable.value != 1:
        raise TestFailure("Complete valid Latin square should be solvable")
    
    if dut.valid.value != 1:
        raise TestFailure("Solution should be valid")
    
    # Verify it matches given rows (which are perfect cyclic shifts)
    for r in range(4):
        for c in range(4):
            expected = (c + r) % 4  # Shift row 0 by r positions
            if dut.grid_out[r][c].value != expected:
                raise TestFailure(f"Row {r}, Col {c}: expected {expected}, got {dut.grid_out[r][c].value}")
    
    print("Test 5 PASSED: All rows pre-filled validation")

print("
=== Superdoku Test Summary ===")
print("All 5 tests should pass for complete 4x4 solver")
