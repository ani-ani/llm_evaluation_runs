import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_matcher(dut):
    # Packed test cases: (list1, list2, list3, expected)
    test_cases = [
        (0x12345678, 0x22312679, 0x21312679, 3),  # Original Test 1
        (0x12345678, 0x22312678, 0x21312678, 4),  # Original Test 2
        (0x12342678, 0x22312678, 0x21312678, 5),  # Original Test 3
        (0x00000000, 0x00000000, 0x00000000, 8),  # All match
        (0x12345678, 0x87654321, 0x11223344, 0)   # None match
    ]
    
    passed = 0
    for i, (l1, l2, l3, expected) in enumerate(test_cases):
        dut.list1.value = l1
        dut.list2.value = l2
        dut.list3.value = l3
        await Timer(1, units='ns')
        result = dut.match_count.value
        if result == expected:
            passed += 1
            dut._log.info(f"Test {i+1} PASS: Expected {expected}, Got {result}")
        else:
            dut._log.error(f"Test {i+1} FAIL: Expected {expected}, Got {result}")
    
    total = len(test_cases)
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed}/{total} tests"