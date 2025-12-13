import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import numpy as np

@cocotb.test()
async def test_first_diff(dut):
    test_cases = [
        # Input list (8 elements), expected output
        ([1, 3, 5, 7, 4, 1, 6, 8], 3), 
        ([1, 2, 3, 4, 5, 6, 7, 8], 1),
        ([2, 4, 6, 8, 10, 12, 14, 16], 3), # 2-(-1)=3
        ([1, 3, 5, 7, 9, 11, 13, 15], -2) # -1-1=-2
    ]
    
    passed = 0
    for input_list, expected in test_cases:
        # Set input values
        for i, val in enumerate(input_list):
            # Convert negative numbers to 2's complement
            if val < 0:
                real_val = val & 0xff
            else:
                real_val = val
            getattr(dut, f"list_{i}").value = real_val
        
        await Timer(1, units='ns')
        
        # Convert output to signed integer
        result = dut.difference.value.signed_integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {input_list} → {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {input_list} → {result}, expected {expected}")
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")