import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_even_checker(dut):
    test_cases = [
        (0, 1),   # 0 is even
        (1, 0),   # 1 is odd
        (2, 1),   # 2 is even
        (3, 0),   # 3 is odd
        (254, 1), # 254 is even
        (255, 0)  # 255 is odd
    ]
    
    passed = 0
    total = len(test_cases)
    
    for (num, expected) in test_cases:
        dut.n.value = num
        await Timer(1, units='ns')
        result = dut.is_even.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {num} => {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {num} => {result}, expected {expected}")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")