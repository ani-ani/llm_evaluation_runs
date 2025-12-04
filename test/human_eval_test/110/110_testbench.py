import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_exchange(dut):
    test_cases = [
        # Original case: [1,2,3,4], [1,2,3,4] -> YES
        ([1,2,3,4], [1,2,3,4], 1),
        # Original case: [1,2,3,4], [1,5,3,4] -> NO
        ([1,2,3,4], [1,5,3,4], 0),
        # Original case: [5,7,3], [2,6,4] -> YES (padded with 0)
        ([5,7,3,0], [2,6,4,0], 1),
        # Original case: [5,7,3], [2,6,3] -> NO (padded with 0)
        ([5,7,3,0], [2,6,3,0], 0),
        # Edge case: [100,200] expanded to 4 elements
        ([100,200,0,0], [200,200,0,0], 1)
    ]
    
    passed = 0
    for lst1, lst2, expected in test_cases:
        for i in range(4):
            dut.lst1[i].value = lst1[i]
            dut.lst2[i].value = lst2[i]
        await Timer(1, units='ns')
        result = dut.result.value
        try:
            assert result == expected, f"Expected {expected} got {result}"
            passed += 1
            dut._log.info(f"PASS: {lst1} + {lst2} => {expected}")
        except AssertionError as e:
            dut._log.error(f"FAIL: {lst1} + {lst2} => {result} (expected {expected})")
    
    total = len(test_cases)
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total