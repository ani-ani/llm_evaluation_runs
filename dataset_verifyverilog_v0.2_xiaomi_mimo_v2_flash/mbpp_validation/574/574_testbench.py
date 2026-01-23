import cocotb
from cocotb.triggers import Timer
import random

# Constants for Q16.16 format
SCALE = 65536
PI_FIXED = int(3.1415 * SCALE)  # 205887
TWO_PI_FIXED = int(6.283 * SCALE)  # 411774

def float_to_fixed(value):
    """Convert float to Q16.16 fixed-point integer"""
    return int(value * SCALE)

def fixed_to_float(value):
    """Convert Q16.16 fixed-point to float"""
    return value / SCALE

def surfacearea_cylinder_sw(r, h):
    """Software reference implementation"""
    r_f = fixed_to_float(r)
    h_f = fixed_to_float(h)
    result = (2 * 3.1415 * r_f * r_f) + (2 * 3.1415 * r_f * h_f)
    return float_to_fixed(result)

@cocotb.test()
async def test_surfacearea_cylinder(dut):
    """Test surface area calculation with multiple test cases"""
    
    # Test cases from the problem
    test_cases = [
        (10.0, 5.0),    # Expected: 942.45
        (4.0, 5.0),     # Expected: 226.188
        (4.0, 10.0),    # Expected: 351.848
    ]
    
    # Additional edge cases
    test_cases.extend([
        (0.0, 5.0),     # Zero radius
        (5.0, 0.0),     # Zero height
        (1.0, 1.0),     # Small values
        (100.0, 50.0),  # Large values
        (3.5, 7.2),     # Decimal values
    ])
    
    passed = 0
    total = len(test_cases)
    
    print(f"
Testing surfacearea_cylinder with {total} cases...
")
    
    for i, (r_float, h_float) in enumerate(test_cases):
        # Convert to fixed-point
        r_fixed = float_to_fixed(r_float)
        h_fixed = float_to_fixed(h_float)
        
        # Expected result
        expected = surfacearea_cylinder_sw(r_fixed, h_fixed)
        
        # Apply inputs
        dut.r.value = r_fixed
        dut.h.value = h_fixed
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Get actual result
        actual = int(dut.result.value)
        
        # Convert to float for display
        expected_float = fixed_to_float(expected)
        actual_float = fixed_to_float(actual)
        
        # Allow small error due to fixed-point precision
        error = abs(actual_float - expected_float)
        error_percent = (error / (expected_float + 1e-9)) * 100
        
        # Check if within tolerance (0.1% relative error or 0.01 absolute)
        tolerance = 0.01
        is_pass = error < tolerance or error_percent < 0.1
        
        if is_pass:
            passed += 1
            status = "PASS"
        else:
            status = "FAIL"
        
        print(f"Test {i+1}: r={r_float:.2f}, h={h_float:.2f}")
        print(f"  Expected: {expected_float:.4f} (0x{expected:08X})")
        print(f"  Actual:   {actual_float:.4f} (0x{actual:08X})")
        print(f"  Error:    {error:.6f} ({error_percent:.4f}%)")
        print(f"  Status:   {status}
")
        
        assert is_pass, f"Test {i+1} failed: expected {expected_float:.4f}, got {actual_float:.4f}"
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}
")
    
    assert passed == total, f"Only {passed}/{total} tests passed"
