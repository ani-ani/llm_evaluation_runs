import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_even_position(dut):
    test_cases = [
        ([3,2,1,0,0,0,0,0], 0),  # Original: [3,2,1] -> False
        ([1,2,3,0,0,0,0,0], 0),  # Original: [1,2,3] -> False
        ([2,1,4,0,0,0,0,0], 1),  # Original: [2,1,4] -> True
        ([0,0,0,0,0,0,0,0], 1),  # All even
        ([1,0,2,0,3,0,4,0], 0)   # Fail at index 0
    ]
    passed = 0
    for vec, expected in test_cases:
        for i in range(8):
            dut.nums[i].value = vec[i]
        await Timer(1, units='ns')
        result = dut.match.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {vec} -> {result}")
        else:
            dut._log.error(f"FAIL: {vec} got {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")