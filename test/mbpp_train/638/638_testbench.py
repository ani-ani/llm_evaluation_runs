import cocotb
from cocotb.triggers import Timer
import math

# Q16.16 conversion functions
def float_to_q1616(x):
    return int(x * (1 << 16)) & 0xFFFFFFFF

def q1616_to_float(x):
    return x / (1 << 16) if x < 0x80000000 else (x - 0x100000000) / (1 << 16)

@cocotb.test()
async def test_wind_chill(dut):
    # Pre-calculated test cases
    test_cases = [
        # (wind_velocity, temperature, expected)
        (120, 35, 40),
        (40, 20, 19),
        (10, 8, 6)
    ]
    
    passed = 0
    for v, t, expected in test_cases:
        dut.wind_velocity.value = v
        dut.temperature.value = t
        await Timer(1, units='ns')
        
        result = dut.wind_chill.value.signed_integer
        dut._log.info(f"Input: v={v}, t={t} => Output: {result} (Expected: {expected})")
        
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Mismatch: v={v}, t={t} got {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)