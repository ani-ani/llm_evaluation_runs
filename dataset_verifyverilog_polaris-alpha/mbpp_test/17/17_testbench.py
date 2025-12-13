import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_square_perimeter(dut):
    test_cases = [
        (10, 40),   # Original Test 1: 4*10=40
        (5, 20),    # Original Test 2: 4*5=20
        (4, 16),    # Original Test 3: 4*4=16
        (0, 0),     # Edge case: zero input
        (255, 1020) # Max 8-bit value: 4*255=1020
    ]
    passed = 0
    for a_val, expected in test_cases:
        dut.a.value = a_val
        await Timer(1, units='ns')
        if dut.perimeter.value == expected:
            passed += 1
            dut._log.info(f"PASS: {a_val}->{expected}")
        else:
            dut._log.error(f"FAIL: {a_val}->{dut.perimeter.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")