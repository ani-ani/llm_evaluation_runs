import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_list_diff(dut):
    # Test cases adapted to 4-bit range (0-15)
    test_cases = [
        # Original Test 1 scaled: [10,15,20,25] -> [10,11,12,13] (since 25>15)
        {"list1": [10,11,12,13], "valid1": [1,1,1,1], 
         "list2": [10,13,12], "valid2": [1,1,1,0],
         "expected": set([11])},
        # Original Test 2 scaled
        {"list1": [1,2,3,4], "valid1": [1,1,1,1],
         "list2": [6,7,1], "valid2": [1,1,1,0],
         "expected": set([2,3,4,6,7])},
        # Original Test 3 scaled
        {"list1": [1,2,3,0], "valid1": [1,1,1,0],
         "list2": [6,7,1,0], "valid2": [1,1,1,0],
         "expected": set([2,3,6,7])},
        # Edge case: empty list
        {"list1": [5,5,5,5], "valid1": [0,0,0,0],
         "list2": [5,6,7,8], "valid2": [1,1,1,1],
         "expected": set([5,6,7,8])}
    ]
    
    passed = 0
    for case in test_cases:
        # Apply inputs
        for i in range(4):
            dut.list1[i].value = case['list1'][i]
            dut.valid1[i].value = case['valid1'][i]
            dut.list2[i].value = case['list2'][i]
            dut.valid2[i].value = case['valid2'][i]
        
        await Timer(10, units='ns')  # Allow combinational settling
        
        # Collect output
        result_size = dut.size.value.integer
        result_set = set()
        for i in range(result_size):
            if i < 8:  # Only check up to our buffer size
                val = dut.result[i].value.integer
                # Only allow unique values
                if val not in result_set:
                    result_set.add(val)
                else:
                    dut._log.error(f"Duplicate value {val} in output")
        
        # Compare with expected
        if result_set == case['expected']:
            passed += 1
            dut._log.info(f"PASS: Got {result_set} == Expected {case['expected']}")
        else:
            dut._log.error(f"FAIL: Got {result_set} != Expected {case['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")