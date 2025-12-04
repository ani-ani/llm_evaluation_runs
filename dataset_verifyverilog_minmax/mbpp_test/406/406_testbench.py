import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_parity(dut):
    test_cases = [
        (12, False),  # 0b00001100 → 2 ones (even)
        (7, True),    # 0b00000111 → 3 ones (odd)
        (10, False),  # 0b00001010 → 2 ones
        (0, False),   # Edge case: 0 ones
        (255, False)  # Edge case: 8 ones (even)
    ]
    passed = 0
    for x, expected in test_cases:
        dut.x.value = x
        await Timer(1, units='ns')
        actual = bool(dut.odd_parity.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: x={x} ({bin(x)}) → parity={actual}")
        else:
            dut._log.error(f"FAIL: x={x} ({bin(x)}) → {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")