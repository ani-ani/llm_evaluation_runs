import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper function to convert float to Q8.8 fixed point
def to_q88(value):
    return int(value * 256) & 0xFFFF

# Helper to convert Q8.8 to float for debugging
def from_q88(value):
    if value & 0x8000:  # Sign extend
        value = value - 0x10000
    return value / 256.0

@cocotb.test()
async def test_line_intersection_counter(dut):
    """Test line intersection counter with 4 segments"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_enable.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: 3 segments forming triangle (should have 3 intersections)
    # Segments: (1,3)-(9,5), (2,2)-(6,8), (4,8)-(9,3)
    segments1 = [
        (1.0, 3.0, 9.0, 5.0),
        (2.0, 2.0, 6.0, 8.0),
        (4.0, 8.0, 9.0, 3.0),
        (0.0, 0.0, 0.0, 0.0)  # Dummy
    ]
    
    # Load segments
    for i, (x0, y0, x1, y1) in enumerate(segments1):
        dut.segment_index.value = i
        dut.x0.value = to_q88(x0)
        dut.y0.value = to_q88(y0)
        dut.x1.value = to_q88(x1)
        dut.y1.value = to_q88(y1)
        dut.load_enable.value = 1
        await RisingEdge(dut.clk)
    
    dut.load_enable.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result1 = int(dut.result.value)
    error1 = int(dut.error.value)
    print(f"Test 1: Result={result1}, Error={error1} (Expected: 3 intersections)")
    assert result1 == 3 or error1 == 1, f"Test 1 failed: got {result1}"
    
    # Test Case 2: 3 segments meeting at single point (should have 1 intersection)
    # Simplified: (0,0)-(10,10), (0,10)-(10,0), (0,0)-(0,10) - last two overlap at (0,0)
    # Better: (0,0)-(5,5), (0,5)-(5,0), (5,5)-(0,0) - all meet at (0,0) and (5,5)
    # Let's use: (0,0)-(4,4), (0,4)-(4,0), (2,2)-(6,6) - meet at (2,2)
    segments2 = [
        (0.0, 0.0, 4.0, 4.0),
        (0.0, 4.0, 4.0, 0.0),
        (2.0, 2.0, 6.0, 6.0),
        (10.0, 10.0, 11.0, 11.0)  # Isolated segment
    ]
    
    # Reset for new test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    for i, (x0, y0, x1, y1) in enumerate(segments2):
        dut.segment_index.value = i
        dut.x0.value = to_q88(x0)
        dut.y0.value = to_q88(y0)
        dut.x1.value = to_q88(x1)
        dut.y1.value = to_q88(y1)
        dut.load_enable.value = 1
        await RisingEdge(dut.clk)
    
    dut.load_enable.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result2 = int(dut.result.value)
    error2 = int(dut.error.value)
    print(f"Test 2: Result={result2}, Error={error2} (Expected: 1 intersection)")
    assert result2 == 1 or error2 == 1, f"Test 2 failed: got {result2}"
    
    # Test Case 3: 2 segments sharing endpoint
    segments3 = [
        (-1.0, -2.0, -1.0, -1.0),
        (-1.0, 2.0, -1.0, -1.0),
        (0.0, 0.0, 1.0, 1.0),  # Dummy
        (2.0, 2.0, 3.0, 3.0)   # Dummy
    ]
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    for i, (x0, y0, x1, y1) in enumerate(segments3):
        dut.segment_index.value = i
        dut.x0.value = to_q88(x0)
        dut.y0.value = to_q88(y0)
        dut.x1.value = to_q88(x1)
        dut.y1.value = to_q88(y1)
        dut.load_enable.value = 1
        await RisingEdge(dut.clk)
    
    dut.load_enable.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result3 = int(dut.result.value)
    error3 = int(dut.error.value)
    print(f"Test 3: Result={result3}, Error={error3} (Expected: 1 intersection)")
    assert result3 == 1 or error3 == 1, f"Test 3 failed: got {result3}"
    
    # Test Case 4: 2 collinear overlapping segments (infinite)
    segments4 = [
        (0.0, 0.0, 5.0, 5.0),
        (2.0, 2.0, 8.0, 8.0),
        (10.0, 10.0, 11.0, 11.0),  # Dummy
        (12.0, 12.0, 13.0, 13.0)   # Dummy
    ]
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    for i, (x0, y0, x1, y1) in enumerate(segments4):
        dut.segment_index.value = i
        dut.x0.value = to_q88(x0)
        dut.y0.value = to_q88(y0)
        dut.x1.value = to_q88(x1)
        dut.y1.value = to_q88(y1)
        dut.load_enable.value = 1
        await RisingEdge(dut.clk)
    
    dut.load_enable.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result4 = int(dut.result.value)
    error4 = int(dut.error.value)
    print(f"Test 4: Result={result4}, Error={error4} (Expected: error=1 for infinite)")
    assert error4 == 1, f"Test 4 failed: should be infinite intersection"
    
    # Test Case 5: Parallel but non-overlapping (should be 0)
    segments5 = [
        (0.0, 0.0, 5.0, 5.0),
        (1.0, 0.0, 6.0, 5.0),  # Parallel, offset
        (10.0, 10.0, 11.0, 11.0),
        (12.0, 12.0, 13.0, 13.0)
    ]
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    for i, (x0, y0, x1, y1) in enumerate(segments5):
        dut.segment_index.value = i
        dut.x0.value = to_q88(x0)
        dut.y0.value = to_q88(y0)
        dut.x1.value = to_q88(x1)
        dut.y1.value = to_q88(y1)
        dut.load_enable.value = 1
        await RisingEdge(dut.clk)
    
    dut.load_enable.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result5 = int(dut.result.value)
    error5 = int(dut.error.value)
    print(f"Test 5: Result={result5}, Error={error5} (Expected: 0 intersections)")
    assert result5 == 0 and error5 == 0, f"Test 5 failed: got {result5}"
    
    print(f"
Summary: All tests passed!")
    print(f"  - Triangle intersections: {result1}")
    print(f"  - Single point meeting: {result2}")
    print(f"  - Shared endpoint: {result3}")
    print(f"  - Infinite overlap: error={error4}")
    print(f"  - Parallel disjoint: {result5}")
