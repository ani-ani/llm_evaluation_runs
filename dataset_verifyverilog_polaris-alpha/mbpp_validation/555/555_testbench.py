import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_difference(dut):
    test_cases = [
        (3, 30),
        (5, 210),
        (2, 6),
        (0, 0),  # Edge case: n=0
        (1, 0),  # Edge case: n=1
        (10, 39600)  # Additional test: n=10 (result=39600)
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')  # Wait for combinational logic
        if dut.result.value.integer == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val}")
        else:
            dut._log.error(f"FAIL: n={n_val} => {dut.result.value.integer}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")