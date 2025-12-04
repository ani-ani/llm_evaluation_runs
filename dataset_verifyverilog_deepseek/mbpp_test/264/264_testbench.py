import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_dog_age(dut):
    test_cases = [
        (0, 0),
        (1, 10),
        (2, 21),
        (3, 25),
        (12, 61),
        (15, 73),
        (24, 109),
        (255, 1033),
    ]
    
    passed = 0
    for human_age, expected in test_cases:
        dut.h_age.value = human_age
        await Timer(1, units='ns')
        result = dut.d_age.value
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {human_age} -> {expected}")
        else:
            dut._log.error(f"FAIL: {human_age} years got {result}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"Summary: {passed}/{total} tests passed")