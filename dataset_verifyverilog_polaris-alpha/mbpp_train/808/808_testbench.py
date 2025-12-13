import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestSuccess

@cocotb.test()
async def test_tuple_checker(dut):
    # Test cases adapted with zero-padding to 8 elements
    test_cases = [
        ((10,4,5,6,8,0,0,0), 6, True),   # Original Test 1
        ((1,2,3,4,5,6,0,0), 7, False),    # Original Test 2
        ((7,8,9,44,11,12,0,0), 11, True), # Original Test 3
        ((0,0,0,0,0,0,0,0), 0, True),     # All zeros case
        ((255,0,0,0,0,0,0,0), 255, True), # Max value first
        ((0,0,0,0,0,0,0,1), 2, False)     # Not found test
    ]
    
    passed = 0
    for tpl, k_val, expected in test_cases:
        # Assign tuple elements
        for i in range(8):
            dut.tuple_elements[i].value = tpl[i]
        dut.K.value = k_val
        
        await Timer(1, units='ns')
        
        if dut.found.value == expected:
            passed += 1
            dut._log.info(f"PASS: {tpl} contains {k_val}? {expected}")
        else:
            dut._log.error(f"FAIL: {tpl} with {k_val} => {dut.found.value} (expected {expected})")
    
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} tests passed")
    if passed < len(test_cases):
        raise TestFailure(f"{len(test_cases)-passed} tests failed")
    else:
        raise TestSuccess("All tests passed")