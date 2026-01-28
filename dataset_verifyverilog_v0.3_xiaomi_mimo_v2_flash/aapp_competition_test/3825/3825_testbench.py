import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_roman_digit_count(dut):
    test_cases = [
        (1, 4),
        (2, 10),
        (3, 20),
        (4, 35),
        (5, 56),
        (6, 83),
        (7, 116),
        (8, 155),
        (9, 198),
        (10, 244),
        (11, 292),
        (12, 341),
        (13, 390),
        (14, 439),
        (55, 2448),
        (100, 4653),
        (150, 7103),
        (1200, 58553),
        (1000, 48753),
        (2000, 97753),
        (5000, 244753),
        (10000, 489753),
        (111199, 5448504),
        (9999999, 489999704),
        (100000000, 4899999753),
        (101232812, 4960407541),
        (500000000, 24499999753),
        (600000000, 29399999753),
        (709000900, 34741043853),
        (999999999, 48999999704),
        (1000000000, 48999999753)
    ]
    
    passed = 0
    failed = 0
    
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(100, units='ns')
        
        if not is_value_defined(dut.result.value):
            dut._log.error(f"FAIL: n={n_val} - Result is undefined")
            failed += 1
            continue
            
        result = int(dut.result.value)
        if result != expected:
            dut._log.error(f"FAIL: n={n_val} - Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"PASS: n={n_val} -> {result}")
            passed += 1
    
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")