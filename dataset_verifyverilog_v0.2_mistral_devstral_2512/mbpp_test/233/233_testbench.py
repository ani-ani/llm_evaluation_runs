import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_lateral_surface_cylinder(dut):
    """Test lateral surface area calculation with Q16.16 fixed-point arithmetic"""
    
    # Helper function to convert float to Q16.16 fixed-point
    def float_to_q16_16(value):
        return int(value * 65536)
    
    # Helper function to convert Q16.16 to float
    def q16_16_to_float(value):
        return value / 65536.0
    
    # Test cases: (r, h, expected_area)
    test_cases = [
        (10, 5, 314.15000000000003),
        (4, 5, 125.66000000000001),
        (4, 10, 251.32000000000002),
        (1, 1, 6.28318),  # Edge case: minimum non-zero
        (255, 255, 255*255*2*3.14159),  # Maximum values
        (0, 10, 0),  # Zero radius
        (10, 0, 0),  # Zero height
        (7, 13, 7*13*2*3.14159),  # Additional test
    ]
    
    passed = 0
    total = len(test_cases)
    
    print("
=== Testing Lateral Surface Cylinder Calculator ===")
    print(f"Fixed-point format: Q16.16 (16 integer, 16 fractional bits)")
    print(f"π approximation: 3.14159
")
    
    for i, (r, h, expected_float) in enumerate(test_cases, 1):
        # Set inputs
        dut.r.value = r
        dut.h.value = h
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result_raw = dut.area.value.integer
        
        # Convert to float for comparison
        result_float = q16_16_to_float(result_raw)
        
        # Calculate expected in Q16.16
        expected_q16 = float_to_q16_16(expected_float)
        
        # Check if within tolerance (0.1% relative error due to fixed-point precision)
        relative_error = abs(result_float - expected_float) / max(abs(expected_float), 1e-9)
        
        test_name = f"Test {i}: r={r}, h={h}"
        
        if relative_error < 0.001:  # 0.1% tolerance
            print(f"✓ {test_name}")
            print(f"  Result: {result_float:.6f} (Q16.16: 0x{result_raw:08X})")
            print(f"  Expected: {expected_float:.6f} (Q16.16: 0x{expected_q16:08X})")
            print(f"  Error: {relative_error*100:.4f}%
")
            passed += 1
        else:
            print(f"✗ {test_name}")
            print(f"  Result: {result_float:.6f} (Q16.16: 0x{result_raw:08X})")
            print(f"  Expected: {expected_float:.6f} (Q16.16: 0x{expected_q16:08X})")
            print(f"  Error: {relative_error*100:.4f}%
")
            raise TestFailure(f"Test {i} failed: error {relative_error*100:.2f}% exceeds 0.1% tolerance")
    
    print(f"=== Summary: {passed}/{total} tests passed ===")