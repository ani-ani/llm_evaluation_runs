import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import math

async def is_prime(n_val):
    if n_val <= 1:
        return False
    if n_val <= 3:
        return True
    if n_val % 2 == 0 or n_val % 3 == 0:
        return False
    i = 5
    while i*i <= n_val:
        if n_val % i == 0 or n_val % (i+2) == 0:
            return False
        i += 6
    return True

@cocotb.test()
async def test_prime_selector(dut):
    test_cases = [
        (7, 34, 12, 34),
        (15, 8, 5, 5),
        (3, 33, 5212, 33),
        (1259, 3, 52, 3),
        (7919, -1, 12, -1),
        (3609, 1245, 583, 583),
        (91, 56, 129, 129),
        (6, 34, 1234, 1234),
        (1, 2, 0, 0),
        (2, 2, 0, 2)
    ]
    passed = 0
    for n_val, x_val, y_val, expected in test_cases:
        dut.n.value = n_val
        dut.x.value = x_val
        dut.y.value = y_val
        await Timer(1, units='ns')
        result = dut.result.value.signed_integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} → {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} → {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")