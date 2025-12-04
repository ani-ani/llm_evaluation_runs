import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_min_length(dut):
    # Convert test cases to presence vectors
    # Original: [[1],[1,2]] → min=1
    test_cases = [
        ([0b1000, 0b1100, 0b0000, 0b0000], 1),
        ([0b1110, 0b1111, 0b1110, 0b0000], 3),  # Original: [[1,2,3],[1,2,3,4]] → adapted min=3
        ([0b1111, 0b1111, 0b0111, 0b0011], 2),  # Original: [[3,3,3],[4,4,4,4]] → adapted min=3 but scaled
        ([0b1001, 0b0011, 0b0100, 0b1111], 2),  # Edge case with mixed lengths
        ([0b0000, 0b0000, 0b0000, 0b0000], 0)   # All empty edge case
    ]
    
    passed = 0
    for inputs, expected in test_cases:
        (s0, s1, s2, s3) = inputs
        dut.sublist0.value = s0
        dut.sublist1.value = s1
        dut.sublist2.value = s2
        dut.sublist3.value = s3
        await Timer(1, units='ns')
        actual = dut.min_length.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: Inputs {[bin(x) for x in inputs]} → {actual}")
        else:
            dut._log.error(f"FAIL: Inputs {[bin(x) for x in inputs]} got {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")