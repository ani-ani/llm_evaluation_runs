import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import math

@cocotb.test()
async def test_adjacent_multiplier(dut):
    test_cases = [
        {"input": [1,5,7,8,10], "expected": [5,35,56,80]},
        {"input": [2,4,5,6,7], "expected": [8,20,30,42]},
        {"input": [12,13,14,9,15], "expected": [156,182,126,135]}
    ]
    
    passed = 0
    
    for case in test_cases:
        # Apply inputs
        for i in range(5):
            dut.in_tuple[i].value = case["input"][i]
        
        await Timer(1, units='ns')
        
        # Check outputs
        correct = True
        for j in range(4):
            actual = dut.out_tuple[j].value.integer
            expected = case["expected"][j]
            if actual != expected:
                dut._log.error(f"Mismatch at position {j}: {actual} vs {expected}")
                correct = False
        
        if correct:
            passed += 1
            input_str = ",".join(map(str, case["input"]))
            dut._log.info(f"PASS: {input_str} → {case['expected']}")
        else:
            input_str = ",".join(map(str, case["input"]))
            dut._log.error(f"FAIL: {input_str} → {[dut.out_tuple[k].value.integer for k in range(4)]}")
    
    total = len(test_cases)
    dut._log.info(f"Test summary: {passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed}/{total} tests"