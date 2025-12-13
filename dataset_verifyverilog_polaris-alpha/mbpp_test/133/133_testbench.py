import cocotb
from cocotb.triggers import Timer
import numpy as np

@cocotb.test()
async def test_sum_neg(dut):
    test_cases = [
        ([2, 4, -6, -9, 11, -12, 14, -5, 17, 0], -32),
        ([10,15,-14,13,-18,12,-20,0,0,0], -52),
        ([19, -65, 57, 39, 152,-639, 121, 44, 90, -190], -894),
        ([1,2,3,4,5,6,7,8,9,10], 0)  # test with no negatives
    ]
    passed = 0
    for idx, (nums, expected) in enumerate(test_cases):
        # Convert to 16-bit 2's complement representation
        for i in range(10):
            val = 0 if i >= len(nums) else nums[i]
            dut.nums[i].value = val if val >= 0 else (1 << 16) + val
        await Timer(10, units='ns')
        result = int(dut.sum_neg.value)
        # Convert signed interpretation
        if result & (1 << 15): result -= 1 << 16
        if result == expected:
            passed += 1
            dut._log.info(f"PASSED Test {idx+1}: Got {result}")
        else:
            dut._log.error(f"FAILED Test {idx+1}: Expected {expected}, got {result}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")