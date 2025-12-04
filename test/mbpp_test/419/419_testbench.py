import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_round_and_sum(dut):
    # Helper function to convert float to Q8.8 fixed-point
    def to_q88(n):
        return int(n * 256 + (0.5 if n >=0 else -0.5)) & 0xFFFF

    test_cases = [
        # (input list, length, expected)
        ([5.0, 2.0, 9.0, 24.3, 29.0], 5, 345),
        ([25.0, 56.7, 89.2], 3, 513),
        ([1.5, 2.3, 3.7], 3, 24),
        ([0.49, 0.51, -0.49, -0.51], 4, 0),  # Tests rounding bounds
        ([255.99] + [0.0]*7, 1, 256*1),      # Max Q8.8 value
    ]

    passed = 0
    for numbers, length, expected in test_cases:
        # Pad input to 8 elements
        padded = list(numbers) + [0.0] * (8 - len(numbers))
        # Apply Q8.8 conversion
        q88_values = [to_q88(n) for n in padded]
        
        # Set DUT inputs
        for i, val in enumerate(q88_values):
            dut.numbers[i].value = val
        dut.length.value = length
        
        await Timer(1, units='ns')
        
        if dut.total.value.signed_integer == expected:
            passed += 1
            dut._log.info(f"PASS: {numbers}(len={length}) → {expected}")
        else:
            dut._log.error(f"FAIL: Input {numbers} len={length}. Got {dut.total.value.signed_integer}, Expected {expected}")
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")