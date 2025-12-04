import cocotb
from cocotb.triggers import Timer
import numpy as np

# Q16.16 helper function
def to_fixed(x):
    return int(x * (1 << 16)) & 0xFFFFFFFF

def from_fixed(x):
    return x / 65536.0 if x < 0x80000000 else (x - 0x100000000) / 65536.0

@cocotb.test()
async def test_closest(dut):
    test_cases = [
        # (input_float, expected_int)
        (10.0, 10),  # "10"
        (14.5, 15),  # "14.5"
        (-15.5, -16), # "-15.5"
        (15.3, 15),  # "15.3"
        (0.0, 0),    # "0"
        (14.5, 15),  # Test away from zero+ (0x8000)
        (-14.5, -15),# Test away from zero-
        (3.999, 4),  # Nearly 4
        (-5.999, -6) # Nearly -6
    ]
    
    passed = 0
    for float_val, expected in test_cases:
        fixed_val = to_fixed(float_val)
        dut.fixed_point_number.value = fixed_val
        await Timer(1, units='ns')
        
        result = dut.rounded_value.value.signed_integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {float_val:.2f} -> {result} (expected {expected})")
        else:
            dut._log.error(f"FAIL: {float_val:.2f} -> {result} (expected {expected}) Q16.16={hex(fixed_val)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)