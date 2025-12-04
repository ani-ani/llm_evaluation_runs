import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_bit_range_count(dut):
    test_cases = [
        (7, 2, 5, 4),
        (10, 3, 10, 5),
        (0, 1, 1, 0),
        (1, 1, 1, 1),
        (3, 2, 3, 2)
    ]
    passed = 0
    for n_val, l_val, r_val, expected in test_cases:
        dut.n.value = n_val
        dut.l.value = l_val - 1  # Convert to 0-indexed for module
        dut.r.value = r_val - 1  # Convert to 0-indexed
        await Timer(1, units='ns')
        result = dut.count.value
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n_val}, l={l_val}, r={r_val} -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")