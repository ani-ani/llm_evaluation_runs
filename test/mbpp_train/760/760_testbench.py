import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_distinct(dut):
    test_cases = [
        ([1,1,1,1,1,1,1,1], True),
        ([1,2,1,2,1,2,1,2], False),
        ([1,2,3,4,5,1,1,1], False),
        ([0,0,0,0,0,0,0,0], True),
        ([255,255,255,255,255,255,255,255], True),
        ([4,4,4,4,4,4,4,5], False)
    ]
    passed = 0
    
    for idx, (numbers, expected) in enumerate(test_cases):
        # Pad test vectors to 8 elements
        padded = numbers + [numbers[0]] * (8 - len(numbers))
        
        for i, val in enumerate(padded):
            dut.arr[i].value = val
        
        await Timer(1, units='ns')
        
        if dut.result.value == int(expected):
            passed += 1
            dut._log.info(f"Test {idx+1} PASS: {padded} => {expected}")
        else:
            dut._log.error(f"Test {idx+1} FAIL: {padded} => {dut.result.value}, expected {int(expected)}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"