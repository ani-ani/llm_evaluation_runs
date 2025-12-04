import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_cube_lsa(dut):
    test_cases = [
        (5, 100),
        (9, 324),
        (10, 400),
        (0, 0),
        (1, 4),
        (32767, 32767*32767*4)  # Max safe input for 32-bit output
    ]
    passed = 0
    for side, expected in test_cases:
        dut.side.value = side
        await Timer(1, units='ns')
        result = dut.lsa.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: side={side} → lsa={result}")
        else:
            dut._log.error(f"FAIL: side={side} → {result}, expected {expected}")
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"{total-passed} tests failed"