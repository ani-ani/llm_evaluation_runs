import cocotb
from cocotb.triggers import Timer
import numpy as np

@cocotb.test()
async def test_score_comparator(dut):
    test_cases = [
        # First test case (pad to 8 elements)
        {'scores': [1,2,3,4,5,1,0,0], 'guesses': [1,2,3,4,2,-2,0,0], 'expected': [0,0,0,0,3,3,0,0]},
        # All zeros
        {'scores': [0]*8, 'guesses': [0]*8, 'expected': [0]*8},
        # Different signs
        {'scores': [1,2,3,0,0,0,0,0], 'guesses': [-1,-2,-3,0,0,0,0,0], 'expected': [2,4,6,0,0,0,0,0]},
        # Partial match
        {'scores': [1,2,3,5,0,0,0,0], 'guesses': [-1,2,3,4,0,0,0,0], 'expected': [2,0,0,1,0,0,0,0]}
    ]
    passed = 0
    for test_idx, tc in enumerate(test_cases):
        # Set inputs
        for i in range(8):
            dut.scores[i].value = tc['scores'][i]
            dut.guesses[i].value = tc['guesses'][i]
        
        await Timer(1, units='ns')
        
        # Check results
        errors = []
        for i in range(8):
            actual = dut.differences[i].value.integer
            expected = tc['expected'][i]
            if actual != expected:
                errors.append(f"Index {i}: got {actual}, expected {expected}")
        
        if not errors:
            passed += 1
            dut._log.info(f"Test {test_idx} PASSED")
        else:
            dut._log.error(f"Test {test_idx} FAILED. Errors: {', '.join(errors)}")
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")