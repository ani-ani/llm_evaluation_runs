import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import math

@cocotb.test()
async def test_max_product(dut):
    # Adjusted test cases (zero-padded to 8 elements)
    test_cases = [
        ([1,2,3,4,7,0,8,4], [7,8]),
        ([0,-1,-2,-4,5,0,-6,0], [-4,-6]),
        ([1,2,3,0,0,0,0,0], [2,3]),
        ([-128, -128, 127, 0,0,0,0,0], [-128, -128]),  # Max negative test
        ([10, 9, 8, 7, 6, 5, 4, 3], [10,9])  # Positive only
    ]

    passed = 0
    for arr_input, expected_pair in test_cases:
        # Convert Python list to Verilog array format
        for i, val in enumerate(arr_input):
            dut.arr_input[i].value = val
        
        await Timer(1, units='ns')  # Combinational delay
        
        # Collect output as sorted tuple for comparison
        result = sorted([int(dut.num1.value), int(dut.num2.value)])
        expected_sorted = sorted(expected_pair)
        
        if result == expected_sorted:
            passed += 1
            dut._log.info(f"PASS: {arr_input} => {result}")
        else:
            dut._log.error(f"FAIL: {arr_input} => {result}, expected {expected_sorted}")
    
    dut._log.info(f"RESULTS: {passed}/{len(test_cases)} tests passed")