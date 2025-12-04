import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_parity_checker(dut):
    tests = [
        # Test 1: Original case (extended)
        ([2,1,4,3,6,7,6,3], 1, "Original Valid"),
        # Test 2: Original 3-element case with proper padding
        ([4,1,2,3,0,5,0,7], 1, "Modified Test2 Padding"),
        # Test 3: Original negative case
        ([1,2,3,3,4,5,6,7], 0, "Original Invalid"),
        # Additional edge cases
        ([0,1,2,3,4,5,6,7], 1, "Perfect Match"),
        ([0,2,4,6,8,10,12,14], 0, "All Even Fail")
    ]
    
    passed = 0
    for nums, expected, name in tests:
        for idx, val in enumerate(nums):
            dut.nums[idx].value = val
        await Timer(1, units='ns')
        actual = dut.is_correct.value
        if actual == expected:
            dut._log.info(f"PASS: {name} -> {expected}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {name} -> Got {actual}, expected {expected}")
    
    total = len(tests)
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    assert passed == total, "Some tests failed"