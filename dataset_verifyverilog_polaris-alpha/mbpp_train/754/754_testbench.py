import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_common_elements(dut):
    test_cases = [
        # Original Test 1 (padded with zeros)
        ([1,1,3,4,5,6,7,0], [0,1,2,3,4,5,7,0], [0,1,2,3,4,5,7,0], [1,7], 2),
        # Original Test 2
        ([1,1,3,4,5,6,7,0], [0,1,2,3,4,6,5,0], [0,1,2,3,4,6,7,0], [1,6], 2),
        # Original Test 3
        ([1,1,3,4,6,5,6,0], [0,1,2,3,4,5,7,0], [0,1,2,3,4,5,7,0], [1,5], 2),
        # Original Test 4
        ([1,2,3,4,6,6,6,0], [0,1,2,3,4,5,7,0], [0,1,2,3,4,5,7,0], [], 0),
        # Edge case: full match
        ([8,8,8,8,8,8,8,8], [8,8,8,8,8,8,8,8], [8,8,8,8,8,8,8,8], [8,8,8,8,8,8,8,8], 8)
    ]
    
    passed = 0
    for l1, l2, l3, expected_result, expected_count in test_cases:
        # Apply inputs
        for i in range(8):
            dut.l1[i].value = l1[i]
            dut.l2[i].value = l2[i]
            dut.l3[i].value = l3[i]
        
        await Timer(1, units='ns')
        
        # Check output
        match_count = dut.count.value
        output_result = [dut.result[i].value for i in range(8)]
        
        # Extract only relevant outputs based on count
        actual_result = [output_result[i] for i in range(match_count)]
        
        if actual_result == expected_result and match_count == expected_count:
            passed += 1
            dut._log.info(f"PASS: {expected_result} (count={expected_count})")
        else:
            dut._log.error(f"FAIL: Inputs={l1},{l2},{l3}")
            dut._log.error(f"  Expected: {expected_result} (count={expected_count})")
            dut._log.error(f"  Actual: {actual_result} (count={match_count})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)