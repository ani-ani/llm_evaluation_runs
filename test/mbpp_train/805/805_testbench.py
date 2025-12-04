import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import numpy as np

@cocotb.test()
async def test_max_sum(dut):
    test_cases = [
        ([[1,2,3], [4,5,6], [10,11,12], [7,8,9]], [10,11,12], 33),
        ([[3,2,1], [6,5,4], [12,11,10], [0,0,0]], [12,11,10], 33),
        ([[2,3,1], [0,0,0], [0,0,0], [0,0,0]], [2,3,1], 6)
    ]
    
    passed = 0
    for idx, (input_lists, expected_list, expected_sum) in enumerate(test_cases):
        # Flatten input to 4x3 array
        for list_idx in range(4):
            if list_idx < len(input_lists):
                for elem_idx in range(3):
                    val = input_lists[list_idx][elem_idx] if elem_idx < len(input_lists[list_idx]) else 0
                    dut.lists.value[list_idx*3 + elem_idx] = val
            else:
                for elem_idx in range(3):
                    dut.lists.value[list_idx*3 + elem_idx] = 0
        
        await Timer(1, units='ns')
        
        # Check output
        out_list = [int(dut.max_list.value[i]) for i in range(3)]
        out_sum = int(dut.max_sum.value)
        
        if out_list == expected_list and out_sum == expected_sum:
            passed += 1
            dut._log.info(f"Test {idx+1} PASS
")
        else:
            dut._log.error(f"Test {idx+1} FAIL: Output list={out_list} (expected {expected_list}), sum={out_sum} (expected {expected_sum})")
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")