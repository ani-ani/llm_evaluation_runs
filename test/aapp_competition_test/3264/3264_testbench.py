import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_coprime_set_counter(dut):
    test_cases = [
        (2, 1),
        (3, 5),
        (4, 21)
    ]
    passed = 0
    for N_val, expected in test_cases:
        dut.N.value = N_val
        await Timer(1, units='ns')
        result = dut.count.value.integer
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: N={N_val}, Result={result}, Expected={expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"