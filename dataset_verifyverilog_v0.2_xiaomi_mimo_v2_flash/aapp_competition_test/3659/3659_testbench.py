import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_bookcase_optimizer(dut):
    """Test the bookcase optimizer module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 4 books from sample
    # Books: (220,29), (195,20), (200,9), (180,30)
    # Expected: 18000 (height: 220+200+180=600, width: max(29,20,9+30=39) = 39, area=600*39=23400)
    # Wait, let's recalculate: optimal is S1={(220,29)}, S2={(195,20),(200,9)}, S3={(180,30)}
    # Heights: 220, 200, 180 sum=600. Widths: 29, 20+9=29, 30 max=30. Area=600*30=18000 ✓
    
    dut.num_books.value = 4
    dut.heights[0].value = 220
    dut.thickness[0].value = 29
    dut.heights[1].value = 195
    dut.thickness[1].value = 20
    dut.heights[2].value = 200
    dut.thickness[2].value = 9
    dut.heights[3].value = 180
    dut.thickness[3].value = 30
    
    # Fill remaining with dummy values
    for i in range(4, 8):
        dut.heights[i].value = 0
        dut.thickness[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (12 cycles as specified)
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check result
    assert dut.done.value == 1, "Done signal should be high"
    result = int(dut.min_area.value)
    print(f"Test 1: Result = {result}, Expected = 18000")
    assert result == 18000, f"Expected 18000, got {result}"
    
    # Test Case 2: 6 books
    # Books: (256,20), (255,30), (254,15), (253,20), (252,15), (251,9)
    # Expected: 29796
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    dut.num_books.value = 6
    dut.heights[0].value = 256
    dut.thickness[0].value = 20
    dut.heights[1].value = 255
    dut.thickness[1].value = 30
    dut.heights[2].value = 254
    dut.thickness[2].value = 15
    dut.heights[3].value = 253
    dut.thickness[3].value = 20
    dut.heights[4].value = 252
    dut.thickness[4].value = 15
    dut.heights[5].value = 251
    dut.thickness[5].value = 9
    
    for i in range(6, 8):
        dut.heights[i].value = 0
        dut.thickness[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    result = int(dut.min_area.value)
    print(f"Test 2: Result = {result}, Expected = 29796")
    assert result == 29796, f"Expected 29796, got {result}"
    
    # Test Case 3: 3 books (minimum case)
    # Books: (200,10), (180,15), (190,20)
    # Must put one book per shelf: heights sum = 570, max width = 20, area = 11400
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    dut.num_books.value = 3
    dut.heights[0].value = 200
    dut.thickness[0].value = 10
    dut.heights[1].value = 180
    dut.thickness[1].value = 15
    dut.heights[2].value = 190
    dut.thickness[2].value = 20
    
    for i in range(3, 8):
        dut.heights[i].value = 0
        dut.thickness[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    result = int(dut.min_area.value)
    expected = (200 + 180 + 190) * 20  # 570 * 20 = 11400
    print(f"Test 3: Result = {result}, Expected = {expected}")
    assert result == expected, f"Expected {expected}, got {result}"
    
    # Test Case 4: Edge case - all same books
    # 3 books: (200,10), (200,10), (200,10)
    # Any partition: heights sum = 600, max width = 10, area = 6000
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    dut.num_books.value = 3
    dut.heights[0].value = 200
    dut.thickness[0].value = 10
    dut.heights[1].value = 200
    dut.thickness[1].value = 10
    dut.heights[2].value = 200
    dut.thickness[2].value = 10
    
    for i in range(3, 8):
        dut.heights[i].value = 0
        dut.thickness[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    result = int(dut.min_area.value)
    expected = 6000
    print(f"Test 4: Result = {result}, Expected = {expected}")
    assert result == expected, f"Expected {expected}, got {result}"
    
    print("All 4/4 tests passed!")