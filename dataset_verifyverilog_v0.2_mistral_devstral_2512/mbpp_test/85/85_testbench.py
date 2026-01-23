import cocotb
from cocotb.triggers import Timer
import math

# Helper function to convert float to Q16.16 fixed point
def float_to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 fixed point to float
def q16_16_to_float(value):
    # Handle signed values
    if value & 0x80000000:
        value = value - 0x100000000
    return value / 65536.0

@cocotb.test()
async def test_sphere_surface_area(dut):
    """Test sphere surface area calculation with various radii"""
    
    # Test cases: radius values and expected surface areas
    test_cases = [
        (10, 1256.6370614359173),
        (15, 2827.4333882308138),
        (20, 5026.548245743669)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for radius_float, expected_float in test_cases:
        # Convert input radius to Q16.16 format
        radius_q16 = float_to_q16_16(radius_float)
        
        # Apply input to DUT
        dut.radius.value = radius_q16
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        result_q16 = dut.surface_area.value.integer
        result_float = q16_16_to_float(result_q16)
        
        # Check with relative tolerance
        rel_error = abs(result_float - expected_float) / expected_float
        
        if rel_error < 0.01:  # Allow ~1% error due to fixed-point precision
            passed += 1
            print(f"PASS: radius={radius_float} -> result={result_float:.6f}, expected={expected_float:.6f}, error={rel_error:.6f}")
        else:
            print(f"FAIL: radius={radius_float} -> result={result_float:.6f}, expected={expected_float:.6f}, error={rel_error:.6f}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
