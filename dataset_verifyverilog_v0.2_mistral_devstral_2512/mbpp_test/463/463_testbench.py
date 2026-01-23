import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def python_max_product(arr):
    """Python reference implementation"""
    n = len(arr)
    max_ending_here = 1
    min_ending_here = 1
    max_so_far = 0
    flag = 0
    for i in range(0, n):
        if arr[i] > 0:
            max_ending_here = max_ending_here * arr[i]
            min_ending_here = min(min_ending_here * arr[i], 1)
            flag = 1
        elif arr[i] == 0:
            max_ending_here = 1
            min_ending_here = 1
        else:
            temp = max_ending_here
            max_ending_here = max(min_ending_here * arr[i], 1)
            min_ending_here = temp * arr[i]
        if (max_so_far < max_ending_here):
            max_so_far = max_ending_here
    if flag == 0 and max_so_far == 0:
        return 0
    return max_so_far

@cocotb.test()
async def test_max_product_subarray(dut):
    """Test maximum product subarray module with various cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_length.value = 0
    for i in range(8):
        setattr(dut.array_data, f'[{i}]', 0)
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([1, -2, -3, 0, 7, -8, -2], 112),
        ([6, -3, -10, 0, 2], 180),
        ([-2, -40, 0, -2, -3], 80),
        ([3, 5], 15),  # Simple positive
        ([-5, -4], 20),  # Two negatives
        ([0, 0, 5], 5),  # Leading zeros
        ([-1, -2, -3], 6),  # All negative
        ([1, 2, 3, 4, 5, 6, 7, 8], 40320),  # Full array
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr, expected in test_cases:
        # Load array into DUT
        dut.array_length.value = len(arr)
        for i, val in enumerate(arr):
            # Convert to 16-bit signed
            if val < 0:
                dut.array_data[i].value = (1 << 16) + val
            else:
                dut.array_data[i].value = val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            raise TestFailure(f"Timeout waiting for done for arr={arr}")
        
        # Read result
        result = dut.result.value
        # Convert from Q16.16 to integer
        result_int = result >> 16
        if result & 0x80000000:  # Sign extension if negative
            result_int = result_int - (1 << 32) >> 16
        
        # Python reference
        expected_result = python_max_product(arr)
        
        print(f"Array: {arr}")
        print(f"  Expected (Python): {expected_result}")
        print(f"  Expected (given):  {expected}")
        print(f"  Got (HW):          {result_int}")
        print(f"  Raw result: 0x{result:08X}")
        
        if result_int == expected_result:
            passed += 1
            print(f"  ✓ PASS
")
        else:
            raise TestFailure(f"Mismatch for arr={arr}: expected {expected_result}, got {result_int}")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    if passed == total:
        print("All tests successful!")
