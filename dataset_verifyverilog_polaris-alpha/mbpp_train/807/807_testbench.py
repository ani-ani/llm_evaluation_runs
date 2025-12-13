import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import random

@cocotb.test()
async def test_first_odd(dut):
    # Test cases with padding (extra elements set to even numbers)
    test_cases = [
        ([1, 3, 5, 0, 0, 0, 0, 0], 1),      # Original Test 1
        ([2, 4, 1, 3, 0, 0, 0, 0], 1),      # Original Test 2
        ([8, 9, 1, 0, 0, 0, 0, 0], 9),      # Original Test 3
        ([2, 4, 6, 8, 10, 12, 14, 16], -1),# All even
        ([-3, 2, 4, 0, 0, 0, 0, 0], -3),    # Negative odd
        ([0, 0, 7, 0, 0, 0, 0, 0], 7)       # Middle odd
    ]
    
    passed = 0
    for idx, (numbers, expected) in enumerate(test_cases):
        # Pad to 8 elements if needed
        padded_nums = list(numbers) + [0]*(8-len(numbers))
        
        # Set inputs
        for i, val in enumerate(padded_nums):
            dut.nums[i].value = val
        
        await Timer(1, units='ns')
        
        result = dut.result.value.signed_integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS {idx}: {numbers} -> {result}")
        else:
            dut._log.error(f"FAIL {idx}: {numbers} -> {result}, expected {expected}")
    
    # Edge case: Multiple odds in different positions
    dut.nums[0].value = 2
    dut.nums[1].value = 3
    dut.nums[2].value = 5
    dut.nums[3].value = 0
    await Timer(1, units='ns')
    if dut.result.value == 3:
        passed +=1
        dut._log.info("PASS Edge case: Correct first odd")
    else:
        dut._log.error(f"FAIL Edge case: Got {dut.result.value}, expected 3")
    
    dut._log.info(f"{passed}/{len(test_cases)+1} tests passed")