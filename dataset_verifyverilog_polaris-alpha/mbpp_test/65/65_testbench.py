import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_list_sum(dut):
    test_cases = [
        # Test 1 adapted (1+2+3+4+5+6=21)
        ({'elements': [1,2,3,4,5,6,0,0], 'valid_mask': 0b11111100}, 21),
        # Test 2 adapted (7+10+15+14+19+41=106)
        ({'elements': [7,10,15,14,19,41,0,0], 'valid_mask': 0b11111100}, 106),
        # Test 3 adapted (10+20+30+40+50+60=210)
        ({'elements': [10,20,30,40,50,60,0,0], 'valid_mask': 0b11111100}, 210),
        # Edge case: full mask
        ({'elements': [10,10,10,10,10,10,10,10], 'valid_mask': 0b11111111}, 80),
        # Partial mask
        ({'elements': [100,100,100,100,0,0,0,0], 'valid_mask': 0b11110000}, 400)
    ]
    passed = 0
    for case, expected in test_cases:
        for i in range(8):
            dut.elements[i].value = case['elements'][i]
        dut.valid_mask.value = case['valid_mask']
        await Timer(1, units='ns')
        if dut.total_sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: Sum={dut.total_sum.value} (expected {expected})")
        else:
            dut._log.error(f"FAIL: Sum={dut.total_sum.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")