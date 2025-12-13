import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_cube_volume(dut):
    test_cases = [
        (3, 27),
        (2, 8),
        (5, 125),
        (15, 3375),  # Max input test
        (0, 0)       # Edge case
    ]
    passed = 0
    for (side, expected) in test_cases:
        dut.side_length.value = side
        await Timer(1, units='ns')
        actual = dut.volume.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {side}^3 = {actual}")
        else:
            dut._log.error(f"FAIL: {side}^3 = {actual}, expected {expected}")
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} passed")