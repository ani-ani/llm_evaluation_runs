import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import random

@cocotb.test()
async def test_list_filter(dut):
    # Convert Python lists to HDL format
    def list_to_logic(lst, length, width=4):
        arr = [0]*8
        for i in range(min(len(lst), 8)):
            if i < length: arr[i] = lst[i]
        return LogicArray(arr, width*8)
    
    test_cases = [
        {"main": [1,2,3,4,5,6,7,8], "main_len":8, "filter":[2,4,6,8], "filter_len":4, "expected":[1,3,5,7], "exp_len":4},
        {"main":[1,2,3,4,5], "main_len":5, "filter":[1,3,5], "filter_len":3, "expected":[2,4], "exp_len":2},
        {"main":[5,10,15], "main_len":3, "filter":[5,7], "filter_len":2, "expected":[10,15], "exp_len":2},
        {"main":[9,1,2], "main_len":3, "filter":[3,9,1], "filter_len":3, "expected":[2], "exp_len":1},
        {"main":[], "main_len":0, "filter":[1], "filter_len":1, "expected":[], "exp_len":0}
    ]

    passed = 0
    for case in test_cases:
        # Set inputs
        dut.main_list.value = list_to_logic(case["main"], case["main_len"])
        dut.filter_list.value = list_to_logic(case["filter"], case["filter_len"])
        dut.main_len.value = case["main_len"]
        dut.filter_len.value = case["filter_len"]
        
        await Timer(1, 'ns')
        
        # Check results
        result_len = dut.result_len.value.integer
        result_valid = [dut.result[i].value.integer for i in range(result_len)]
        
        if result_len == case["exp_len"] and result_valid == case["expected"]:
            passed += 1
            dut._log.info(f"PASS: {case['main']} \\ {case['filter']} -> {result_valid}")
        else:
            dut._log.error(f"FAIL: {case['main']} \\ {case['filter']} -> {result_valid} (expected {case['expected']})")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")