import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_array_diff(dut):
    # Modified test cases with 4 elements each
    test_cases = [
        ([1,2,3,4], 3),   # Original Test 1 + padded element
        ([4,5,12,12], 8), # Original Test 2 becomes [4,5,12,12]
        ([9,2,3,3], 7),   # Original Test 3 becomes [9,2,3,3]
        ([5,5,5,5], 0),   # New test: all same values
        ([0,15,7,3], 15)  # New test: edge case min=0, max=15
    ]
    
    passed = 0
    for idx, (numbers, expected) in enumerate(test_cases):
        dut.nums_0.value = numbers[0]
        dut.nums_1.value = numbers[1]
        dut.nums_2.value = numbers[2]
        dut.nums_3.value = numbers[3]
        await Timer(1, units='ns')
        
        if dut.diff.value == expected:
            passed += 1
            dut._log.info(f"Test {idx} PASS: {numbers} -> {int(dut.diff.value)}")
        else:
            dut._log.error(f"Test {idx} FAIL: {numbers} -> {int(dut.diff.value)} (expected {expected})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure("Some tests failed")