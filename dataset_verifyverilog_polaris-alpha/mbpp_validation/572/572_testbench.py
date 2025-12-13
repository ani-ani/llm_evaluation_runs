import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import random

@cocotb.test()
async def test_unique(dut):
    test_cases = [
        # Test 1 (Original: [1,2,3,2,3,4,5])
        {"in": [1,2,3,2,3,4,5,0], "len": 7, "expected": {1,4,5}},
        # Test 2 (Original: [1,2,3,2,4,5])
        {"in": [1,2,3,2,4,5,0,0], "len": 6, "expected": {1,3,4,5}},
        # Test 3 (Original: [1,2,3,4,5])
        {"in": [1,2,3,4,5,0,0,0], "len": 5, "expected": {1,2,3,4,5}},
        # Additional edge case: all duplicates
        {"in": [5,5,5,5,5,5,5,5], "len": 8, "expected": set()},
        # Size limit test
        {"in": [1,1,2,3,4,5,6,7], "len": 8, "expected": {2,3,4,5,6,7}}
    ]
    
    passed = 0
    for case in test_cases:
        # Set inputs
        for i in range(8):
            dut.nums[i].value = case["in"][i]
        dut.length.value = case["len"]
        
        await Timer(1, "ns")
        
        # Collect output
        result_set = set()
        valid_mask = int(dut.valid_mask.value)
        
        for i in range(8):
            if (valid_mask >> i) & 1:
                val = dut.unique_nums[i].value.integer
                if val != 0:  # Ignore zero padding
                    result_set.add(val)
        
        # Verify against expected
        if result_set == case["expected"]:
            passed += 1
            dut._log.info(f"PASS: Input={case['in'][:case['len']]} → Output={result_set}")
        else:
            dut._log.error(f"FAIL: Input={case['in'][:case['len']]}
  Expected={case['expected']}
  Got={result_set}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")