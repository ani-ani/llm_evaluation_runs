import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_degree_to_radian(dut):
    test_cases = [
        (90, 102960),  # 90 * 1144 = 102960 (≈1.5708 in Q16.16)
        (60, 68640),   # 60 * 1144 = 68640 (≈1.04718)
        (120, 137280), # 120 * 1144 = 137280 (≈2.09436)
        (0, 0),        # Edge case: 0 degrees
        (180, 205920)  # Max test case: 180 degrees
    ]
    passed = 0
    for degree, expected in test_cases:
        dut.degree.value = degree
        await Timer(1, units='ns')
        actual = dut.radian.value
        if int(actual) == expected:
            passed += 1
            dut._log.info(f"PASS: degree={degree} → radian=0x{int(actual):08X}")
        else:
            dut._log.error(f"FAIL: degree={degree} got 0x{int(actual):08X} expected 0x{expected:08X}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")