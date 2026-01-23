import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def float_to_q16_16(f):
    """Convert float to Q16.16 fixed-point format"""
    return int(f * 65536) & 0xFFFFFFFF

def q16_16_to_float(q):
    """Convert Q16.16 to float for verification"""
    if q & 0x80000000:  # Negative number
        return (q - 0x100000000) / 65536.0
    return q / 65536.0

@cocotb.test()
async def test_find_closest_elements(dut):
    """Test find_closest_elements module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in_valid.value = 0
    dut.numbers.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases with expected results
    test_cases = [
        # (input_array, expected_small, expected_large)
        ([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 3.9, 4.0),
        ([1.0, 2.0, 5.9, 4.0, 5.0], 5.0, 5.9),
        ([1.0, 2.0, 3.0, 4.0, 5.0, 2.2], 2.0, 2.2),
        ([1.0, 2.0, 3.0, 4.0, 5.0, 2.0], 2.0, 2.0),
        ([1.1, 2.2, 3.1, 4.1, 5.1], 2.2, 3.1),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_nums, exp_small, exp_large) in enumerate(test_cases):
        print(f"
Test {i+1}: Input = {input_nums}")
        print(f"Expected: ({exp_small}, {exp_large})")
        
        # Pad array to N=8 with 0 values
        N = 8
        padded = input_nums + [0.0] * (N - len(input_nums))
        
        # Convert to Q16.16 and load
        for idx, num in enumerate(padded):
            q_val = float_to_q16_16(num)
            dut.numbers[idx].value = q_val
        
        dut.data_in_valid.value = 0xFF  # All 8 valid
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 100 cycles for N=8)
        timeout = 100
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Check if valid
        if dut.valid.value != 1:
            raise TestFailure(f"Test {i+1}: Valid signal not high")
        
        # Read results
        result_small = q16_16_to_float(int(dut.smaller.value))
        result_large = q16_16_to_float(int(dut.larger.value))
        
        print(f"Got: ({result_small}, {result_large})")
        
        # Check results with tolerance for floating-point
        tolerance = 0.001
        if abs(result_small - exp_small) < tolerance and abs(result_large - exp_large) < tolerance:
            print(f"✓ Test {i+1} PASSED")
            passed += 1
        else:
            raise TestFailure(f"Test {i+1} FAILED: Expected ({exp_small}, {exp_large}), got ({result_small}, {result_large})")
        
        await RisingEdge(dut.clk)
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
