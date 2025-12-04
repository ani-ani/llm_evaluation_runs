import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_sphere(dut):
    
    # Q16.16 conversion helper
    def q16(value):
        return int(value * (1 << 16))
    
    # Test cases with Q16.16 tolerances (±2 LSB)
    test_cases = [
        (0,  0),
        (10,  q16(4 * math.pi * 100)),
        (15,  q16(4 * math.pi * 225)),
        (20,  q16(4 * math.pi * 400)),
        (127, q16(4 * math.pi * 16129))
    ]
    
    passed = 0
    for r, expected in test_cases:
        dut.r.value = r
        await Timer(10, units='ns')  # Combinational delay
        
        # Allow ±2 LSB tolerance for fixed-point rounding
        actual = dut.surfacearea.value.integer
        diff = abs(actual - expected)
        if diff <= 2:
            passed += 1
            dut._log.info(f"PASS: r={r} SA={actual} (expect {expected}, diff={diff} LSB)")
        else:
            dut._log.error(f"FAIL: r={r} got {actual} != {expected} (diff={diff} LSB)")
            
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")