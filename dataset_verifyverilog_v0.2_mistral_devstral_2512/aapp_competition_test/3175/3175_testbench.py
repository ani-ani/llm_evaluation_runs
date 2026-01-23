import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import math

# Helper function to convert decimal to Q16.16 format
def to_q16_16(value):
    return int(value * 65536)

# Helper function to compute expected area
def compute_expected_area(segments):
    from collections import Counter
    from math import tan, pi
    
    if len(segments) < 3:
        return 0
    
    freq = Counter(segments)
    max_area = 0.0
    
    # Try all possible polygon sizes from 3 to len(segments)
    for k in range(3, min(len(segments) + 1, 9)):
        # For regular polygon of size k, need k equal segments
        # Try each possible segment length
        for length, count in freq.items():
            if count >= k:
                s = length
                area = (k * s * s) / (4 * tan(pi / k))
                max_area = max(max_area, area)
    
    return max_area

@cocotb.test()
async def test_max_polygon_area(dut):
    """Test max polygon area computation"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_segment.value = 0
    dut.segment_length.value = 0
    dut.num_segments.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([1, 1, 1, 1], 1.0),      # Square with side 1
        ([1, 1, 1], 0.433),       # Equilateral triangle
        ([1, 1, 2, 2, 7], 2.0),   # Should form optimal polygon
    ]
    
    for segments, expected in test_cases:
        dut._log.info(f"Testing segments {segments}, expected {expected}")
        
        # Reset state
        dut.start.value = 0
        dut.load_segment.value = 0
        await RisingEdge(dut.clk)
        
        # Load segments
        for seg in segments:
            dut.segment_length.value = seg
            dut.load_segment.value = 1
            await RisingEdge(dut.clk)
            dut.load_segment.value = 0
            await RisingEdge(dut.clk)
        
        # Set num_segments and start
        dut.num_segments.value = len(segments)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 150:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 150:
            raise TestFailure(f"Timeout waiting for done signal")
        
        # Read result
        result_q16_16 = int(dut.max_area.value)
        result = result_q16_16 / 65536.0
        
        # Allow 0.005 absolute error as per problem statement
        error = abs(result - expected)
        dut._log.info(f"Result: {result} (Q16.16: {result_q16_16}), Expected: {expected}, Error: {error}")
        
        if error > 0.005:
            raise TestFailure(f"Error {error} exceeds tolerance 0.005")
        
        await RisingEdge(dut.clk)
    
    # Test edge case: no valid polygon
    dut._log.info("Testing edge case: insufficient segments")
    dut.start.value = 0
    dut.load_segment.value = 0
    await RisingEdge(dut.clk)
    
    # Load only 2 segments
    dut.segment_length.value = 1
    dut.load_segment.value = 1
    await RisingEdge(dut.clk)
    dut.load_segment.value = 0
    await RisingEdge(dut.clk)
    
    dut.segment_length.value = 1
    dut.load_segment.value = 1
    await RisingEdge(dut.clk)
    dut.load_segment.value = 0
    await RisingEdge(dut.clk)
    
    dut.num_segments.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 150:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result_q16_16 = int(dut.max_area.value)
    result = result_q16_16 / 65536.0
    
    if result != 0:
        raise TestFailure(f"Expected 0 for insufficient segments, got {result}")
    
    dut._log.info("All tests passed!")