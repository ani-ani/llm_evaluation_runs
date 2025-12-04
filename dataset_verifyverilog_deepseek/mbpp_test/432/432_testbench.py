import cocotb
from cocotb.triggers import Timer
import math

# Q16.16 conversion helpers
def to_fixed(num):
    return int(num * (1 << 16))

def from_fixed(fixed):
    return fixed / (1 << 16)

@cocotb.test()
async def test_median(dut):
    # Test cases from original problem + edge cases (in Q16.16 format)
    test_cases = [
        (15, 25, 35, 20.0),
        (10, 20, 30, 15.0),
        (6, 9, 4, 7.5),
        (0, 0, 0, 0.0),        # Edge: zero inputs
        (32767, 32767, 0, 32767.0), # Max positive before 32-bit overflow
        (1, 3, 2, 2.0)         # Test integer result
    ]
    
    passed = 0
    for b1, b2, h, exp in test_cases:
        dut.base1.value = to_fixed(b1)
        dut.base2.value = to_fixed(b2)
        dut.height.value = to_fixed(h)
        await Timer(1, units='ns')  # Wait for combinational logic
        
        expected = to_fixed(exp)
        actual = dut.median.value.integer
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {b1}+{b2}→{exp}")
        else:
            computed = from_fixed(actual)
            dut._log.error(f"FAIL: {b1}+{b2}={computed:.5f}, expected {exp}")
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")