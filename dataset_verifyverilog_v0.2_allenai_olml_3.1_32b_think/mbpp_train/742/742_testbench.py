import cocotb
from cocotb.triggers import Timer
import math

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point format"""
    return int(value * 65536) & 0xFFFFFFFF

def q16_16_to_float(value):
    """Convert Q16.16 fixed-point to float"""
    # Handle signed values
    if value & 0x80000000:
        value = value - 0x100000000
    return value / 65536.0

def q16_16_to_hex(value):
    """Convert to hex string for display"""
    if value < 0:
        value = value + 0x100000000
    return f"0x{value:08X}"

@cocotb.test()
async def test_tetrahedron_area(dut):
    """Test tetrahedron area calculation with multiple test cases"""
    
    # Test cases: (side_length, expected_area)
    test_cases = [
        (3.0, 15.588457268119894),
        (20.0, 692.8203230275509),
        (10.0, 173.20508075688772),
        (1.0, 1.7320508075688772),      # Edge case: small value
        (50.0, 4330.127018922193),      # Edge case: larger value
    ]
    
    passed = 0
    total = len(test_cases)
    
    print("
=== Tetrahedron Area Test Results ===")
    print(f"{'Side':<10} {'Expected':<20} {'Got':<20} {'Status'}")
    print("-" * 65)
    
    for side_float, expected_float in test_cases:
        # Convert inputs to Q16.16
        side_q16 = float_to_q16_16(side_float)
        expected_q16 = float_to_q16_16(expected_float)
        
        # Apply input
        dut.side.value = side_q16
        await Timer(10, units='ns')
        
        # Read output
        result_q16 = int(dut.area.value)
        result_float = q16_16_to_float(result_q16)
        
        # Calculate error
        expected_hex = q16_16_to_hex(expected_q16)
        result_hex = q16_16_to_hex(result_q16)
        
        # Allow small error due to fixed-point precision
        error = abs(result_float - expected_float)
        is_pass = error < 0.01  # Within 0.01 tolerance
        
        if is_pass:
            passed += 1
            status = "✓ PASS"
        else:
            status = "✗ FAIL"
        
        print(f"{side_float:<10.1f} {expected_float:<20.6f} {result_float:<20.6f} {status}")
        print(f"           Expected: {expected_hex} | Got: {result_hex} | Error: {error:.6f}")
        
        # Assertion with detailed message
        assert is_pass, f"Side={side_float}: expected {expected_float:.6f}, got {result_float:.6f}, error={error:.6f}"
    
    print("-" * 65)
    print(f"Results: {passed}/{total} tests passed")
    print("
=== Test Complete ===
")
