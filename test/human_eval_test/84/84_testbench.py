import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sum(dut):
    test_cases = [
        (1000, "1"),
        (150, "110"),
        (147, "1100"),
        (333, "1001"),
        (963, "10010")
    ]
    passed = 0
    for N, expected in test_cases:
        dut.N.value = N
        await Timer(1, units='ns')
        actual_val = dut.sum_bin.value.integer
        actual_bin = bin(actual_val)[2:]  # Convert to binary string
        if actual_bin == expected:
            passed += 1
            dut._log.info(f"PASS: N={N} → {actual_bin}")
        else:
            dut._log.error(f"FAIL: N={N} → {actual_bin}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")