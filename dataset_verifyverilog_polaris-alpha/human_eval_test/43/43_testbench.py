import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_pairs(dut):
    # Test cases (padded with zeros to 8 elements)
    test_cases = [
        ([1, 3, 5, 0, 0, 0, 0, 0], 0),
        ([1, 3, -2, 1, 0, 0, 0, 0], 0),
        ([1, 2, 3, 7, 0, 0, 0, 0], 0),
        ([2, 4, -5, 3, 5, 7, 0, 0], 1),  # -5+5=0
        ([1, 0, 0, 0, 0, 0, 0, 0], 0),
        ([-3, 9, -1, 3, 2, 30, 0, 0], 1),  # -3+3=0
        ([-3, 9, -1, 3, 2, 31, 0, 0], 1),  # -3+3=0
        ([-3, 9, -1, 4, 2, 30, 0, 0], 0),
        ([-4, 4, 5, -5, 0, 0, 0, 0], 1)   # Two valid pairs
    ]
    
    passed = 0
    for inputs, expected in test_cases:
        # Apply inputs (twos complement conversion)
        for i, val in enumerate(inputs):
            if val < 0:
                # Convert negative to 6-bit twos complement
                bin_val = val & 0x3f
                getattr(dut, f'l_{i}').value = bin_val
            else:
                getattr(dut, f'l_{i}').value = val
        
        await Timer(1, units='ns')
        
        result = dut.out.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {inputs[:6]} -> {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {inputs[:6]} -> {result}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total