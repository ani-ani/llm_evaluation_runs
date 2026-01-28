import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_dif_square(dut):
    test_cases = [
        (5, 1, "5 mod 4 = 1 (can be 3^2 - 2^2)"),
        (10, 0, "10 mod 4 = 2 (cannot)"),
        (15, 1, "15 mod 4 = 3 (can be 8^2 - 7^2)"),
        (1, 1, "1 mod 4 = 1"),
        (2, 0, "2 mod 4 = 2"),
        (3, 1, "3 mod 4 = 3"),
        (4, 1, "4 mod 4 = 0"),
        (6, 0, "6 mod 4 = 2"),
        (7, 1, "7 mod 4 = 3"),
        (8, 1, "8 mod 4 = 0"),
        (9, 1, "9 mod 4 = 1"),
        (10, 0, "10 mod 4 = 2"),
        (11, 1, "11 mod 4 = 3"),
        (12, 1, "12 mod 4 = 0"),
        (13, 1, "13 mod 4 = 1"),
        (14, 0, "14 mod 4 = 2"),
        (16, 1, "16 mod 4 = 0"),
        (18, 0, "18 mod 4 = 2"),
        (20, 1, "20 mod 4 = 0"),
        (22, 0, "22 mod 4 = 2"),
        (25, 1, "25 mod 4 = 1"),
        (26, 0, "26 mod 4 = 2"),
        (30, 0, "30 mod 4 = 2"),
        (31, 1, "31 mod 4 = 3"),
        (32, 1, "32 mod 4 = 0"),
        (34, 0, "34 mod 4 = 2"),
        (62, 0, "62 mod 4 = 2"),
        (63, 1, "63 mod 4 = 3"),
        (64, 1, "64 mod 4 = 0"),
        (66, 0, "66 mod 4 = 2"),
        (126, 0, "126 mod 4 = 2"),
        (127, 1, "127 mod 4 = 3"),
        (128, 1, "128 mod 4 = 0"),
        (130, 0, "130 mod 4 = 2"),
        (254, 0, "254 mod 4 = 2"),
        (255, 1, "255 mod 4 = 3"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_input, expected, description) in enumerate(test_cases):
        dut.n.value = n_input
        await Timer(10, units='ns')
        
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1}: FAIL - Result undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result == expected:
            cocotb.log.info(f"Test {i+1}: PASS - n={n_input}, result={result}")
            passed += 1
        else:
            cocotb.log.error(f"Test {i+1}: FAIL - n={n_input}, expected {expected}, got {result}")
            failed += 1
    
    cocotb.log.info(f"Summary: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
