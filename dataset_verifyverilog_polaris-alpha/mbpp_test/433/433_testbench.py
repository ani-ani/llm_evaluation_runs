import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_array_comparator(dut):
    test_cases = [
        # Test 1 (Original Test Case 1)
        {"arr": [1,2,3,4,5,0,0,0], "number": 4, "expected": 0},
        # Test 2 (Original Test Case 2)
        {"arr": [2,3,4,5,6,0,0,0], "number": 8, "expected": 1},
        # Test 3 (Original Test Case 3)
        {"arr": [9,7,4,8,6,1,0,0], "number": 11, "expected": 1},
        # Additional edge cases
        {"arr": [15,15,15,15,15,15,15,15], "number": 15, "expected": 0},
        {"arr": [0,0,0,0,0,0,0,0], "number": 1, "expected": 1}
    ]
    
    passed = 0
    
    for case in test_cases:
        # Convert array to 8-element format
        arr_padded = case["arr"] + [0]*(8 - len(case["arr"]))
        
        # Set inputs
        for i, val in enumerate(arr_padded):
            dut.arr[i].value = val
        dut.number.value = case["number"]
        
        await Timer(1, units='ns')
        
        if dut.result.value == case["expected"]:
            passed += 1
            dut._log.info(f"PASS: Number={case['number']}, Max={max(case['arr'])}, Result={dut.result.value}")
        else:
            dut._log.error(f"FAIL: Number={case['number']}, Max={max(case['arr'])}, Got={dut.result.value}, Expected={case['expected']}")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")