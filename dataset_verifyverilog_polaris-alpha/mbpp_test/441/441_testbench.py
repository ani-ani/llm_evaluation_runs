import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_surface(dut):
    test_cases = [
        (5, 150),
        (3, 54),
        (10, 600),
        (0, 0),   # Edge case: zero length
        (8, 384)  # Additional test
    ]
    passed = 0
    for l, expected in test_cases:
        dut.l.value = l
        await Timer(1, units='ns')
        result = dut.surface_area.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: l={l} got {result}")
        else:
            dut._log.error(f"FAIL: l={l} got {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")