import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.data_in.value = 0
    dut.count_in.value = 0
    dut.done_in.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')

def compute_expected(n, arr):
    """Compute which values appear in exactly one contiguous segment in circular array"""
    if n == 0:
        return []
    
    # Find unique values
    unique_vals = sorted(set(arr))
    valid_values = []
    
    for val in unique_vals:
        # Find all positions where val appears
        positions = [i for i, x in enumerate(arr) if x == val]
        
        # Check if positions form one contiguous segment in circular array
        # Method: check gaps between consecutive positions (circular)
        n_occurrences = len(positions)
        if n_occurrences == 1:
            valid_values.append(val)
            continue
        
        # Sort positions (they should be sorted already)
        positions.sort()
        
        # Check if there's only one "gap" in the circular sense
        # Count gaps (where distance > 1)
        gaps = 0
        for i in range(n_occurrences):
            curr = positions[i]
            next_pos = positions[(i + 1) % n_occurrences]
            if i == n_occurrences - 1:
                # Wrap around
                dist = (next_pos - curr) % n
            else:
                dist = next_pos - curr
            if dist != 1:
                gaps += 1
        
        # If exactly one gap, it's contiguous (one segment)
        if gaps == 1:
            valid_values.append(val)
    
    return valid_values

@cocotb.test()
async def test_guessing_circle_basic(dut):
    """Test basic functionality with sample inputs"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        ([1, 2, 3], [1, 2, 3]),
        ([1, 1, 2], []),
        ([1, 2, 1, 3], []),
        ([1, 2, 3, 4, 1], [1]),
    ]
    
    for test_idx, (arr, expected) in enumerate(test_cases):
        dut._log.info(f"
Test case {test_idx + 1}: input={arr}, expected={expected}")
        
        await reset_dut(dut)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send data
        n = len(arr)
        for i, val in enumerate(arr):
            dut.data_in.value = val
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
            await Timer(1, units='ns')  # Small gap
        
        # Send count and done
        dut.count_in.value = n
        await RisingEdge(dut.clk)
        dut.done_in.value = 1
        await RisingEdge(dut.clk)
        dut.done_in.value = 0
        
        # Wait for results
        results = []
        timeout = 500
        cycles = 0
        
        while cycles < timeout:
            await RisingEdge(dut.clk)
            if dut.output_done.value == 1:
                # Collect final result
                if dut.result_valid.value == 1:
                    results.append(int(dut.result_value.value))
                break
            
            if dut.result_valid.value == 1:
                val = int(dut.result_value.value)
                results.append(val)
            
            cycles += 1
        
        # Sort results for comparison
        results.sort()
        
        if results != expected:
            raise TestFailure(f"Test {test_idx+1} failed: got {results}, expected {expected}")
        
        dut._log.info(f"Test {test_idx+1} passed: {results}")
    
    dut._log.info(f"All {len(test_cases)} tests passed!")

@cocotb.test()
async def test_guessing_circle_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test with single element (n=1)
    # Expected: value appears once, valid
    await reset_dut(dut)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.data_in.value = 5
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    dut.count_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0
    
    # Wait and collect
    results = []
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            results.append(int(dut.result_value.value))
        if dut.output_done.value == 1:
            break
    
    if results != [5]:
        raise TestFailure(f"Single element test failed: got {results}, expected [5]")
    dut._log.info("Single element test passed")

@cocotb.test()
async def test_guessing_circle_two_same(dut):
    """Test case with two consecutive same values"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Input: [1, 1, 2, 3]
    # 1 appears twice consecutively - valid
    # 2 appears once - valid
    # 3 appears once - valid
    arr = [1, 1, 2, 3]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for val in arr:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        await Timer(1, units='ns')
    
    dut.count_in.value = 4
    await RisingEdge(dut.clk)
    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0
    
    results = []
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            results.append(int(dut.result_value.value))
        if dut.output_done.value == 1:
            break
    
    expected = [1, 2, 3]
    if sorted(results) != expected:
        raise TestFailure(f"Two same test failed: got {results}, expected {expected}")
    dut._log.info("Two same test passed")

@cocotb.test()
async def test_guessing_circle_circular_boundary(dut):
    """Test circular wrap-around behavior"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Input: [3, 1, 2, 1] -> 1 appears at indices 1 and 3 (not consecutive in linear, but consecutive in circular)
    # In circular: positions 1,3 -> distance 1 and 3. Not contiguous (gap at 2 and wrap)
    # So 1 is NOT valid
    # 3: index 0 - valid
    # 2: index 2 - valid
    arr = [3, 1, 2, 1]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for val in arr:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        await Timer(1, units='ns')
    
    dut.count_in.value = 4
    await RisingEdge(dut.clk)
    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0
    
    results = []
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            results.append(int(dut.result_value.value))
        if dut.output_done.value == 1:
            break
    
    expected = [2, 3]
    if sorted(results) != expected:
        raise TestFailure(f"Circular boundary test failed: got {results}, expected {expected}")
    dut._log.info("Circular boundary test passed")

@cocotb.test()
async def test_guessing_circle_all_different(dut):
    """Test case with all different values"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Input: [5, 3, 8, 1]
    # All appear once - all valid
    arr = [5, 3, 8, 1]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for val in arr:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        await Timer(1, units='ns')
    
    dut.count_in.value = 4
    await RisingEdge(dut.clk)
    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0
    
    results = []
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            results.append(int(dut.result_value.value))
        if dut.output_done.value == 1:
            break
    
    expected = [1, 3, 5, 8]
    if sorted(results) != expected:
        raise TestFailure(f"All different test failed: got {results}, expected {expected}")
    dut._log.info("All different test passed")
