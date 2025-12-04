import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_fruit_distribution(dut):
    # Convert original test cases to numeric inputs
    test_cases = [
        # (apples, oranges, total, expected)
        (5,  6,  19,  8),
        (5,  6,  21, 10),
        (0,  1,   3,  2),
        (1,  0,   3,  2),
        (2,  3, 100, 95),
        (2,  3,   5,  0),
        (1,100, 120, 19)
    ]
    # Add edge cases
    test_cases += [
        (0, 0, 255, 255),  # All mangoes
        (255, 0, 255, 0),  # Edge case 1
        (0, 255, 255, 0),  # Edge case 2
        (127, 127, 255, 1) # 255 - 254 = 1
    ]

    passed = 0
    for a, o, t, expected in test_cases:
        dut.apples.value = a
        dut.oranges.value = o
        dut.total.value = t
        await Timer(1, units='ns')  # Wait for comb logic
        
        # Handle 8-bit unsigned wrapping
        actual = LogicArray(dut.mangoes.value).integer
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {a}+{o}+{actual}={t} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {t}-{a}-{o}={actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")