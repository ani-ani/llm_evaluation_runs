import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def calculate_shortest_subarray(arr, K):
    """Calculate shortest subarray containing all numbers 1..K"""
    n = len(arr)
    min_len = float('inf')
    found = False
    
    for i in range(n):
        counts = {x: 0 for x in range(1, K+1)}
        for j in range(i, n):
            val = arr[j]
            if 1 <= val <= K:
                counts[val] += 1
            # Check if all values present
            if all(counts[x] > 0 for x in range(1, K+1)):
                length = j - i + 1
                if length < min_len:
                    min_len = length
                    found = True
                break  # Found minimal for this start
    
    return min_len if found else -1

@cocotb.test()
async def test_shortest_subarray_solver(dut):
    """Test shortest subarray solver with updates"""
    
    # Parameters
    N = 16
    K = 4
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.query_type.value = 0
    dut.pos.value = 0
    dut.new_value.value = 0
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    await cocotb.start_soon(clock.start())
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Initial array: [1,2,3,2,1,1,1,1,1,1,1,1,1,1,1,1]
    arr = [1,2,3,2,1,1,1,1,1,1,1,1,1,1,1,1]
    
    print("
=== Test 1: Initial Query ===")
    expected = calculate_shortest_subarray(arr, K)
    print(f"Array: {arr}")
    print(f"Expected: {expected}")
    
    # Send query type 1
    dut.query_type.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 256 cycles)
    cycles = 0
    while not dut.processing_done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.result_valid.value:
        result = int(dut.shortest_length.value)
        if result == 63:
            result = -1
        print(f"Got: {result}")
        assert result == expected, f"Test 1 failed: expected {expected}, got {result}"
        print("Test 1 PASSED")
    else:
        print("ERROR: result_valid not high")
        assert False
    
    await RisingEdge(dut.clk)
    
    # Test 2: Update pos 2 (0-indexed) to value 3
    print("
=== Test 2: Update and Query ===")
    # Update pos 3 (1-indexed) to 3 - but we use 0-indexed
    # Original: arr[2] = 3, change to 3 (same)
    # Actually from sample: pos 3 (1-indexed) means index 2, change to 3
    # But sample shows change to 3 makes array [2,3,3,2]
    # Wait: original is [2,3,1,2] at indices 0-3
    # Update pos 3 (1-indexed) -> index 2, value 3
    # New arr: [2,3,3,2] -> missing 1, so expected -1
    
    # Our test array: update pos 3 (1-indexed) = index 2
    # arr[2] is currently 3, change to 3 (no change? Wait sample)
    # Sample: [2,3,1,2] -> update pos 3 to 3 -> [2,3,3,2] -> no 1
    # But our array is longer: [1,2,3,2,1,1,...]
    # Let's update index 2 (pos 3 in 1-indexed) to 4 (different)
    
    dut.query_type.value = 0
    dut.pos.value = 2  # 0-indexed
    dut.new_value.value = 4  # Change arr[2] from 3 to 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for update completion
    while not dut.processing_done.value:
        await RisingEdge(dut.clk)
    
    arr[2] = 4  # Update Python array
    print(f"Updated array: {arr}")
    
    # Query again
    await RisingEdge(dut.clk)
    dut.query_type.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = calculate_shortest_subarray(arr, K)
    print(f"Expected: {expected}")
    
    cycles = 0
    while not dut.processing_done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.result_valid.value:
        result = int(dut.shortest_length.value)
        if result == 63:
            result = -1
        print(f"Got: {result}")
        assert result == expected, f"Test 2 failed: expected {expected}, got {result}"
        print("Test 2 PASSED")
    else:
        assert False
    
    await RisingEdge(dut.clk)
    
    # Test 3: Update to restore all values
    print("
=== Test 3: Restore and Query ===")
    # Change index 2 back to 3
    dut.query_type.value = 0
    dut.pos.value = 2
    dut.new_value.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.processing_done.value:
        await RisingEdge(dut.clk)
    
    arr[2] = 3
    # Also change index 0 to 2
    await RisingEdge(dut.clk)
    dut.query_type.value = 0
    dut.pos.value = 0
    dut.new_value.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.processing_done.value:
        await RisingEdge(dut.clk)
    
    arr[0] = 2
    print(f"Updated array: {arr}")
    
    # Query
    await RisingEdge(dut.clk)
    dut.query_type.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = calculate_shortest_subarray(arr, K)
    print(f"Expected: {expected}")
    
    cycles = 0
    while not dut.processing_done.value and cycles < 300:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.result_valid.value:
        result = int(dut.shortest_length.value)
        if result == 63:
            result = -1
        print(f"Got: {result}")
        assert result == expected, f"Test 3 failed: expected {expected}, got {result}"
        print("Test 3 PASSED")
    else:
        assert False
    
    print("
=== Summary: All 3 tests passed ===")