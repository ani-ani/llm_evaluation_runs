import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_divisible(dut):
    test_cases = [
        (12345, False),  # 1-2+3-4+5 = 3 → not divisible
        (121, True),     # 1-2+1 = 0 → divisible
        (1212, False),   # 1-2+1-2 = -2 → 2 not divisible
        (0, True),       # Divisible by all
        (11, True),      # Direct multiple
        (22, True),      # Direct multiple
        (65535, False)   # 6-5+5-3+5 = 8 → not divisible
    ]
    passed = 0
    for num, expected in test_cases:
        dut.n.value = num
        await Timer(1, units='ns')
        result = dut.is_divisible.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {num} → {expected}")
        else:
            dut._log.error(f"FAIL: {num} → {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")