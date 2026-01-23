import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure, TestSuccess

# Color encoding mapping
COLOR_MAP = {'BLUE': 0, 'RED': 1, 'WHITE': 2, 'ORANGE': 3}

def encode_offer(color, start, end):
    """Encode offer as 11-bit value: [1:0]=color, [6:2]=start, [11:7]=end"""
    color_enc = COLOR_MAP[color]
    # Note: In module, offer_end is separate, but for test we pass individual signals
    return color_enc, start, end

@cocotb.test()
async def test_fence_painter_basic(dut):
    """Test basic two-color fence painting"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.offer_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: BLUE 1 8, RED 9 16
    dut.dut.log.info("Test 1: Two non-overlapping offers")
    
    # Load offers
    offers = [
        ('BLUE', 1, 8),
        ('RED', 9, 16)
    ]
    
    for i, (color, start, end) in enumerate(offers):
        color_enc, start_enc, end_enc = encode_offer(color, start, end)
        dut.offer_color.value = color_enc
        dut.offer_start.value = start_enc
        dut.offer_end.value = end_enc
        dut.offer_index.value = i
        dut.offer_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.offer_valid.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not finish in time")
    
    if not dut.possible.value:
        raise TestFailure("Should be possible")
    
    if dut.result.value != 2:
        raise TestFailure(f"Expected 2 offers, got {int(dut.result.value)}")
    
    dut.dut.log.info("Test 1 passed")

@cocotb.test()
async def test_fence_painter_three_colors(dut):
    """Test with three overlapping offers covering full fence"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.offer_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: BLUE 1 12, RED 4 16, WHITE 10 16
    dut.dut.log.info("Test 2: Three overlapping offers")
    
    offers = [
        ('BLUE', 1, 12),
        ('RED', 4, 16),
        ('WHITE', 10, 16)
    ]
    
    for i, (color, start, end) in enumerate(offers):
        color_enc, start_enc, end_enc = encode_offer(color, start, end)
        dut.offer_color.value = color_enc
        dut.offer_start.value = start_enc
        dut.offer_end.value = end_enc
        dut.offer_index.value = i
        dut.offer_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.offer_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not finish")
    
    if not dut.possible.value:
        raise TestFailure("Should be possible")
    
    if dut.result.value != 3:
        raise TestFailure(f"Expected 3 offers, got {int(dut.result.value)}")
    
    dut.dut.log.info("Test 2 passed")

@cocotb.test()
async def test_fence_painter_impossible_gap(dut):
    """Test gap in coverage - should be impossible"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.offer_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.dut.log.info("Test 3: Gap in coverage")
    
    offers = [
        ('BLUE', 1, 8),
        ('RED', 10, 16)
    ]
    
    for i, (color, start, end) in enumerate(offers):
        color_enc, start_enc, end_enc = encode_offer(color, start, end)
        dut.offer_color.value = color_enc
        dut.offer_start.value = start_enc
        dut.offer_end.value = end_enc
        dut.offer_index.value = i
        dut.offer_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.offer_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not finish")
    
    if dut.possible.value:
        raise TestFailure("Should be impossible due to gap at section 9")
    
    dut.dut.log.info("Test 3 passed")

@cocotb.test()
async def test_fence_painter_four_colors(dut):
    """Test with 4 different colors - should be impossible"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.offer_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.dut.log.info("Test 4: Four colors required")
    
    offers = [
        ('BLUE', 1, 6),
        ('RED', 4, 10),
        ('WHITE', 8, 14),
        ('ORANGE', 12, 16)
    ]
    
    for i, (color, start, end) in enumerate(offers):
        color_enc, start_enc, end_enc = encode_offer(color, start, end)
        dut.offer_color.value = color_enc
        dut.offer_start.value = start_enc
        dut.offer_end.value = end_enc
        dut.offer_index.value = i
        dut.offer_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.offer_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(30):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not finish")
    
    # This should be impossible because 4 colors needed
    if dut.possible.value:
        raise TestFailure("Should be impossible - 4 colors required")
    
    dut.dut.log.info("Test 4 passed")

@cocotb.test()
async def test_fence_painter_one_offer(dut):
    """Test single offer covering whole fence"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.offer_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.dut.log.info("Test 5: Single offer covering all")
    
    offers = [
        ('BLUE', 1, 16)
    ]
    
    for i, (color, start, end) in enumerate(offers):
        color_enc, start_enc, end_enc = encode_offer(color, start, end)
        dut.offer_color.value = color_enc
        dut.offer_start.value = start_enc
        dut.offer_end.value = end_enc
        dut.offer_index.value = i
        dut.offer_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.offer_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not finish")
    
    if not dut.possible.value:
        raise TestFailure("Should be possible")
    
    if dut.result.value != 1:
        raise TestFailure(f"Expected 1 offer, got {int(dut.result.value)}")
    
    dut.dut.log.info("Test 5 passed")

@cocotb.test()
async def test_fence_painter_overlapping_same_color(dut):
    """Test overlapping offers with same color"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.offer_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.dut.log.info("Test 6: Overlapping same color")
    
    offers = [
        ('BLUE', 1, 10),
        ('BLUE', 5, 16)
    ]
    
    for i, (color, start, end) in enumerate(offers):
        color_enc, start_enc, end_enc = encode_offer(color, start, end)
        dut.offer_color.value = color_enc
        dut.offer_start.value = start_enc
        dut.offer_end.value = end_enc
        dut.offer_index.value = i
        dut.offer_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.offer_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not finish")
    
    if not dut.possible.value:
        raise TestFailure("Should be possible")
    
    # Should pick only one offer (the one extending further)
    if dut.result.value > 2:
        raise TestFailure(f"Expected 1-2 offers, got {int(dut.result.value)}")
    
    dut.dut.log.info("Test 6 passed")

print("All fence painter tests defined")