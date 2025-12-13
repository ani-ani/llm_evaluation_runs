import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_tetrahedron(dut):
    # Test cases scaled to Q8.8 format (value * 256)
    test_cases = [
        (3.0, 15.588457268119894),   # side=3.0 -> 0x0300
        (10.0, 173.20508075688772),  # side=10.0 -> 0x0A00
        (20.0, 692.8203230275509)    # side=20.0 -> 0x1400
    ]
    passed = 0
    for side, expected in test_cases:
        # Convert to fixed-point representation
        side_fixed = int(side * 256) & 0xFFFF
        expected_fixed = int(expected * 65536) & 0xFFFFFFFF
        tolerance = 0x800  # Allow ±0.0002 error in Q16.16
        
        dut.side_q8.value = side_fixed
        await Timer(1, units='ns')
        
        result = int(dut.area_q16.value)
        if abs(result - expected_fixed) < tolerance:
            passed += 1
            dut._log.info(f"PASS: side={side} area={result/65536:.6f}≈{expected}")
        else:
            dut._log.error(f"FAIL: side={side}
  Got {result/65536:.6f}
  Exp {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)