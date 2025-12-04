import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_volume(dut):
    test_cases = [
        (10, 8, 6, 240),   # Original Test 1
        (3, 2, 2, 6),      # Original Test 2
        (1, 2, 1, 1),      # Original Test 3
        (15, 10, 12, 900//2)  # Additional edge case
    ]
    passed = 0
    for l, b, h, expected in test_cases:
        dut.l.value = l
        dut.b.value = b
        dut.h.value = h
        await Timer(1, units='ns')
        actual = dut.volume.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {l}×{b}×{h}/2 = {actual}")
        else:
            dut._log.error(f"FAIL: {l}×{b}×{h}/2 = {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")