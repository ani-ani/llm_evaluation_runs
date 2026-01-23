import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def solve_python(arr):
    """Python reference for the problem"""
    n = len(arr)
    if n == 0:
        return 0
    
    # Try all possible subsegments to remove
    min_remove = n
    
    for l in range(n + 1):
        for r in range(l - 1, n):
            # Removed subsegment is arr[l...r] (inclusive)
            # Remaining elements are arr[0...l-1] and arr[r+1...n-1]
            remaining = arr[:l] + arr[r+1:]
            if len(set(remaining)) == len(remaining):
                min_remove = min(min_remove, r - l + 1)
    return min_remove

@cocotb.test()
async def test_min_subsegment_removal(dut):
    """Test the min_subsegment_removal module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr_in.value = 0
    dut.n_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    # Format: (n, arr)
    test_cases = [
        (3, [1, 2, 3]),       # Already distinct, remove 0
        (4, [1, 1, 2, 2]),    # Remove 2 elements (middle)
        (5, [1, 4, 1, 4, 9]), # Remove 2 elements
        (4, [1, 1, 1, 1]),    # Remove 3 elements (keep 1)
        (1, [5]),             # Remove 0
        (2, [1, 1]),          # Remove 1
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, arr in test_cases:
        dut._log.info(f"Testing n={n}, arr={arr}")
        
        # Calculate expected
        expected = solve_python(arr)
        dut._log.info(f"Expected result: {expected}")
        
        # Load array into DUT
        # Assuming arr_in is a sequential input: we present values one by one
        # The prompt implies arr_in is a single port, likely updated per cycle
        # Let's assume we need to feed data while start is asserted or via a separate control flow
        # Adaptation: The prompt says 'input [7:0] arr_in'. 
        # Let's assume we feed values sequentially over N cycles.
        
        dut.n_in.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed data
        for i in range(n):
            dut.arr_in.value = arr[i]
            # We might need a signal to indicate valid data, but prompt doesn't specify.
            # Let's assume the module expects data on arr_in when in LOAD state.
            # We will wait for a few cycles or check internal logic.
            # For simplicity in this testbench, we assume arr_in is sampled when start is high or in subsequent cycles.
            # To be safe, let's drive arr_in and wait for state progression.
            # Since the prompt doesn't specify a 'valid' input, we might need to hold the value or pulse it.
            # Let's assume the DUT has a mechanism to ingest data. 
            # If arr_in is a port, we'll drive it.
            # We will inject data in the cycles following start.
            await RisingEdge(dut.clk)
        
        # Wait for completion
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
            # If arr_in is unused after loading, set to 0
            dut.arr_in.value = 0
            
        if timeout >= 100:
            raise TestFailure(f"Module did not finish for n={n}, arr={arr}")
            
        # Check result
        result = int(dut.result.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Result={result}")
        else:
            dut._log.error(f"FAIL: Got {result}, Expected {expected}")
            
        # Reset for next test (optional, but good practice)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
