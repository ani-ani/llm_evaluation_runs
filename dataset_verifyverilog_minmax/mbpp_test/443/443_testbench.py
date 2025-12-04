import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_min_finder(dut):
    test_cases = [
        ([1, 2, 3, -4, -6, 0, 0, 0], -6),
        ([1, 2, 3, -8, -9, 127, 127, 127], -9),
        ([1, 2, 3, 4, -1, 5, 6, 7], -1),
        ([-5, -10, -3, -2, -7, -1, -4, -8], -10),
        ([5, 4, 3, 2, 1, 0, -1, -2], -2)
    ]
    
    passed = 0
    for i, (inputs, expected) in enumerate(test_cases):
        # Apply test vectors
        for idx, val in enumerate(inputs):
            dut.numbers[idx].value = val
        
        # Wait for combinational logic to settle
        await Timer(1, units='ns')
        
        # Get and check result
        result = dut.min_value.value.signed_integer
        if result == expected:
            passed += 1
            dut._log.info(f"Test {i+1} PASS: {inputs} -> {result}")
        else:
            dut._log.error(f"Test {i+1} FAIL: {inputs} -> {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")