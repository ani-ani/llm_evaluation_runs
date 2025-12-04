import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_closest_num(dut):
    test_cases = [
        (11, 10),
        (7, 6),
        (12, 11)
    ]
    
    passed = 0
    for N_val, expected in test_cases:
        dut.N.value = N_val
        await Timer(1, units='ns')
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: N={N_val} result={dut.result.value}")
        else:
            dut._log.error(f"FAIL: N={N_val} got {dut.result.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")