import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import math

def float_to_q16_16(value):
    """Convert a Python float to Q16.16 integer representation."""
    return int(value * 65536)

@cocotb.test()
async def test_cylinder_volume(dut):
    """Test the cylinder volume calculation with multiple test cases."""
    
    # Test cases: (radius, height, expected_volume)
    # Python calculation: volume = 3.1415 * r * r * h
    # We must convert expected result to Q16.16 format
    test_cases = [
        (10, 5),
        (4, 5),
        (4, 10)
    ]
    
    # Tolerance for fixed-point calculation (approx 0.001 relative)
    # Q16.16 has resolution of 1/65536 ≈ 0.000015
    # Allow a few LSBs of error
    tolerance_bits = 100  # Allow 100 units of error
    
    passed = 0
    total = len(test_cases)
    
    for r, h in test_cases:
        # Calculate expected value using Python (reference)
        # Note: Python uses 3.1415 as per problem statement
        expected_float = 3.1415 * r * r * h
        expected_q16 = float_to_q16_16(expected_float)
        
        # Set inputs
        dut.radius.value = r
        dut.height.value = h
        
        # Wait for combinational logic to settle
        # In a real simulation, we might need a clock edge if the module is sequential
        # But if it is purely combinational, we just wait a small amount of time
        await Timer(10, units='ns')
        
        # Read output
        # Cast to integer for comparison
        actual = int(dut.volume.value)
        
        # Check result
        if abs(actual - expected_q16) <= tolerance_bits:
            passed += 1
            print(f"Test Passed: r={r}, h={h}. Expected={expected_q16} ({expected_float:.4f}), Got={actual}")
        else:
            print(f"Test Failed: r={r}, h={h}. Expected={expected_q16} ({expected_float:.4f}), Got={actual}")
            
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
