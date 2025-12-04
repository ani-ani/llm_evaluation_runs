import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_circumference(dut):
    # Q16.16 conversion helper
    def to_fixed(val):
        return int(val * 65536)
    
    # Test cases (original scaled to fixed-point)
    test_cases = [
        (10.0, 62.830),  # Fixed-point inputs
        (5.0, 31.415),
        (4.0, 25.132),
        (0.0, 0.0)      # Edge case
    ]
    
    for radius, expected in test_cases:
        # Apply Q16.16 inputs
        dut.radius_i.value = to_fixed(radius)
        
        # Allow combinational logic to settle
        await Timer(1, units='ns')
        
        # Convert output back to float
        result = dut.circumference_o.value.signed_integer / 65536.0
        
        # Check with tolerance (due to fixed-point approximation)
        tol = 0.001
        assert abs(result - expected) < tol, f"FAIL: radius={radius} got {result:.6f}, expected {expected}"
        dut._log.info(f"PASS: radius={radius} => {result:.6f} (expected {expected})")
    
    dut._log.info(f"{len(test_cases)}/{len(test_cases)} tests passed")