import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import math

@cocotb.test()
async def test_min_heap_checker(dut):
    test_cases = [
        {'arr': [1,2,3,4,5,6,0,0], 'size': 6, 'expected': 1},
        {'arr': [2,3,4,5,10,15,0,0], 'size': 6, 'expected': 1},
        {'arr': [2,10,4,5,3,15,0,0], 'size': 6, 'expected': 0},
        {'arr': [5,0,0,0,0,0,0,0], 'size': 1, 'expected': 1},
        {'arr': [3,4,0,0,0,0,0,0], 'size': 2, 'expected': 1}
    ]
    passed = 0
    
    for case in test_cases:
        dut.size.value = case['size']
        for i in range(8):
            if i < len(case['arr']):
                dut.arr[i].value = case['arr'][i]
            else:
                dut.arr[i].value = 0
        await Timer(1, units='ns')
        
        if int(dut.is_min_heap.value) == case['expected']:
            passed += 1
            dut._log.info(f"PASS: Size {case['size']} {case['arr']} => {case['expected']}")
        else:
            dut._log.error(f"FAIL: Size {case['size']} {case['arr']} => {dut.is_min_heap.value}, expected {case['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")