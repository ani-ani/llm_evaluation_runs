import cocotb
from cocotb.triggers import Timer
import math

def float_to_q8_8(value):
    """Convert float to Q8.8 format (8 integer, 8 fractional bits)"""
    return int(value * 256)

def q16_16_to_float(value):
    """Convert Q16.16 format to float"""
    return value / 65536.0

def float_to_q16_16(value):
    """Convert float to Q16.16 format (16 integer, 16 fractional bits)"""
    return int(value * 65536)

@cocotb.test()
async def test_deg_to_rad(dut):
    """Test degree to radian conversion using fixed-point arithmetic"""
    
    # Test cases: (degrees, expected_radians)
    test_cases = [
        (90, 1.5707963267948966),
        (60, 1.0471975511965976),
        (120, 2.0943951023931953),
        (0, 0.0),
        (180, math.pi),
        (45, 0.7853981633974483),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for degrees, expected_radians in test_cases:
        # Convert input to Q8.8 format
        input_q8_8 = float_to_q8_8(degrees)
        
        # Apply input to DUT
        dut.degree.value = input_q8_8
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        output_q16_16 = dut.radian.value
        
        # Convert to float for comparison
        actual_radians = q16_16_to_float(int(output_q16_16))
        
        # Calculate error tolerance (account for fixed-point precision)
        tolerance = 0.001  # ~0.06% error tolerance
        error = abs(actual_radians - expected_radians)
        
        print(f"Degrees: {degrees}, Expected: {expected_radians:.6f}, Actual: {actual_radians:.6f}, Error: {error:.6f}")
        
        # Allow small tolerance for fixed-point rounding
        if error < tolerance:
            passed += 1
        else:
            dut._log.error(f"Test failed for {degrees}°: expected {expected_radians:.6f}, got {actual_radians:.6f}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
