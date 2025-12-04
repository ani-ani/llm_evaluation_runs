import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_pair_xor_sum(dut):
    test_cases = [
        # Original test cases padded to 4 elements
        # (data_0, data_1, data_2, data_3, expected)
        (5, 9, 7, 6, 47),  # Original Test 1
        (7, 3, 5, 0, 12),  # Original Test 2 (0-padded)
        (7, 3, 0, 0, 4),   # Original Test 3 (0-padded)
        # Edge case testing
        (255, 255, 255, 255, 0),    # All same
        (1, 2, 4, 8, 1+2+4+8+3+5+9+6+12+6+10+12)
    ]
    passed = 0
    
    for case in test_cases:
        dut.data_0.value = case[0]
        dut.data_1.value = case[1]
        dut.data_2.value = case[2]
        dut.data_3.value = case[3]
        expected = case[4]
        
        await Timer(1, units='ns')
        
        if dut.total_sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: Inputs={case[0:4]} Got {int(dut.total_sum.value)} Expected {expected}")
        else:
            dut._log.error(f"FAIL: Inputs={case[0:4]} Got {int(dut.total_sum.value)} Expected {expected}")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")