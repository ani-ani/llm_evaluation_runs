import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_below_threshold(dut):
    test_cases = [
        # (list, threshold, expected)
        ([1, 2, 4, 10], 100, 1),
        ([1, 20, 4, 10], 5, 0),
        ([1, 20, 4, 10], 21, 1),
        ([1, 20, 4, 10], 22, 1),
        ([1, 8, 4, 10], 11, 1),
        ([1, 8, 4, 10], 10, 0)
    ]
    
    passed = 0
    for data, threshold, expected in test_cases:
        # Assign array elements
        dut.l_0.value = data[0]
        dut.l_1.value = data[1]
        dut.l_2.value = data[2]
        dut.l_3.value = data[3]
        dut.threshold.value = threshold
        
        await Timer(1, units='ns')  # Wait for combinational logic
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {data} < {threshold} = {expected}")
        else:
            dut._log.error(f"FAIL: {data} < {threshold} => {dut.result.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure("Some tests failed")