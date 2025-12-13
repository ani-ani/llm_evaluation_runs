import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import random

@cocotb.test()
async def test_dissimilar(dut):
    # Original test cases scaled to 6-bit width
    test_cases = [
        # Test 1
        {"t1": (3, 4, 5, 6), "t2": (5, 7, 4, 10), "expected": {3,6,7,10}},
        # Test 2
        {"t1": (1, 2, 3, 4), "t2": (7, 2, 3, 9), "expected": {1,4,7,9}},
        # Test 3
        {"t1": (21, 11, 25, 26), "t2": (26, 34, 21, 36), "expected": {11,25,34,36}}
    ]
    
    passed = 0
    for case in test_cases:
        # Assign tuple values
        dut.t1_0.value = case["t1"][0]
        dut.t1_1.value = case["t1"][1]
        dut.t1_2.value = case["t1"][2]
        dut.t1_3.value = case["t1"][3]
        
        dut.t2_0.value = case["t2"][0]
        dut.t2_1.value = case["t2"][1]
        dut.t2_2.value = case["t2"][2]
        dut.t2_3.value = case["t2"][3]
        
        await Timer(1, units='ns')
        
        # Collect valid outputs
        valid = LogicArray(dut.valid_mask.value)
        outputs = set()
        for i in range(8):
            if valid[i]:
                outputs.add(int(dut.dissimilar[i].value))
        
        # Verify sets match
        expected = case["expected"]
        if outputs == expected:
            passed += 1
            dut._log.info(f"PASS: Inputs {case['t1']} vs {case['t2']} → {sorted(outputs)}")
        else:
            dut._log.error(f"FAIL: Got {sorted(outputs)} expected {sorted(expected)}")
    
    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")