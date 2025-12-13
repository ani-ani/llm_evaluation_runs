import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_powers_game(dut):
    test_cases = [
        (1, 1),  # Vasya
        (2, 0),  # Petya
        (8, 0),  # Petya
        (255, 1),  # Edge case: maximum input
        (25, 1),  # Vasya (from sample pattern)
        (53, 1),  # Vasya
        (10, 1)   # Vasya
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.winner.value
        if result == expected:
            passed += 1
        else:
            winner_name = "Vasya" if result else "Petya"
            expected_name = "Vasya" if expected else "Petya"
            dut._log.error(f"n={n_val}: Got {winner_name}, Expected {expected_name}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")