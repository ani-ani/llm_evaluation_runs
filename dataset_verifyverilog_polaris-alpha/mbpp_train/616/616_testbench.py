import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_tuple_modulo(dut):
    # Define test cases (padded to 8 elements with don't-cares)
    test_cases = [
        # Test 1: Original case (first 4 elements meaningful)
        {'t1': [10,4,5,6,0,0,0,0], 't2': [5,6,7,5,1,1,1,1], 'exp': [0,4,5,1,0,0,0,0]},
        # Test 2: Original case
        {'t1': [11,5,6,7,0,0,0,0], 't2': [6,7,8,6,1,1,1,1], 'exp': [5,5,6,1,0,0,0,0]},
        # Test 3: Original case
        {'t1': [12,6,7,8,0,0,0,0], 't2': [7,8,9,7,1,1,1,1], 'exp': [5,6,7,1,0,0,0,0]},
        # Additional edge cases
        {'t1': [255,0,1,2,3,4,5,6], 't2': [1,1,1,2,3,4,0,7], 'exp': [0,0,0,0,0,0,0,6]}  # Note: div-by-0 handled as 0
    ]

    passed = 0
    for case in test_cases:
        for i in range(8):
            dut.tuple1[i].value = case['t1'][i]
            dut.tuple2[i].value = case['t2'][i]
        await Timer(1, units='ns')
        error = False
        for i in range(8):
            if case['t2'][i] != 0:  # Skip div-by-0 elements
                actual = dut.result[i].value
                if actual != case['exp'][i]:
                    dut._log.error(f"Index {i}: {case['t1'][i]}%{case['t2'][i]}={actual}, expected {case['exp'][i]}")
                    error = True
        if not error:
            passed += 1
            dut._log.info(f"Passed test case: {case['t1'][:4]}...")
    dut._log.info(f"
Test summary: {passed}/{len(test_cases)} tests passed")