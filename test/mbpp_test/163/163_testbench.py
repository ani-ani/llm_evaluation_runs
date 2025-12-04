import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_poly_area(dut):
    test_cases = [
        (4, 20, 400.0),
        (10, 15, 1731.197),
        (9, 7, 302.909),
        (3, 10, 43.3013),  # Added edge case
        (16, 25, 1568.63)  # Max valid sides
    ]

    passed = 0
    for sides, length, expected in test_cases:
        dut.sides.value = sides
        dut.length.value = length
        await Timer(1, units='ns')
        actual = dut.area.value / 65536.0
        tolerance = expected * 0.001
        if abs(actual - expected) <= tolerance:
            passed += 1
            dut._log.info(f"PASS: sides={sides}, length={length} => {actual:.3f} (expected {expected:.3f})")
        else:
            dut._log.error(f"FAIL: sides={sides}, length={length} => {actual:.3f}, expected {expected:.3f}±{tolerance:.3f}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")

    # Test invalid input
    dut.sides.value = 2
    dut.length.value = 10
    await Timer(1, units='ns')
    assert dut.area.value == 0, "Invalid sides should return 0"