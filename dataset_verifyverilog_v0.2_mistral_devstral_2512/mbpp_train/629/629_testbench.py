import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_filter_even(dut):
    """Test the filter_even module with various inputs"""
    
    # Test cases mapped to 8-element arrays
    # Test 1: [1, 2, 3, 4, 5, 0, 0, 0] -> Expected evens: [2, 4, 0], count=3
    # Test 2: [4, 5, 6, 7, 8, 0, 1, 0] -> Expected evens: [4, 6, 8, 0, 0], count=5 (padded with 0)
    # Test 3: [8, 12, 15, 19, 0, 0, 0, 0] -> Expected evens: [8, 12, 0, 0], count=2
    
    test_cases = [
        ([1, 2, 3, 4, 5, 0, 0, 0], [2, 4, 0], 3),
        ([4, 5, 6, 7, 8, 0, 1, 0], [4, 6, 8, 0, 0], 5),
        ([8, 12, 15, 19, 0, 0, 0, 0], [8, 12, 0, 0], 2),
        ([255, 254, 1, 128, 33, 64, 0, 255], [254, 128, 64, 0], 4) # Edge cases
    ]

    for i, (inputs, expected_vals, expected_count) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: {inputs[:4]}...")
        
        # Set inputs
        for idx in range(8):
            dut.data_in[idx].value = inputs[idx]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check count
        count = int(dut.count.value)
        assert count == expected_count, f"Test {i+1} Failed: Expected count {expected_count}, got {count}"
        
        # Check output values
        for j in range(count):
            val = int(dut.data_out[j].value)
            assert val == expected_vals[j], f"Test {i+1} Failed: Expected data_out[{j}]={expected_vals[j]}, got {val}"
            
    dut._log.info("All tests passed!")