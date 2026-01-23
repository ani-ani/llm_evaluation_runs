import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import math

# Q16.16 conversion helper
def to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Q16.16 to float conversion
def from_q16_16(value):
    # Handle signed values
    if value & 0x80000000:
        value = value - 0x100000000
    return value / 65536.0

@cocotb.test()
async def test_cone_volume(dut):
    """Test cone volume calculation with multiple test cases"""
    
    # Test cases: (radius, height, expected_volume)
    test_cases = [
        (5.0, 12.0, 314.15926535897927),
        (10.0, 15.0, 1570.7963267948965),
        (19.0, 17.0, 6426.651371693521),
        # Additional edge cases
        (1.0, 1.0, 1.0471975511965976),  # Small values
        (25.0, 30.0, 19634.954084936208),  # Larger values
        (0.0, 10.0, 0.0),  # Zero radius
    ]
    
    passed = 0
    total = len(test_cases)
    
    for r, h, expected in test_cases:
        # Convert inputs to Q16.16
        r_fixed = to_q16_16(r)
        h_fixed = to_q16_16(h)
        
        # Apply inputs
        dut.radius.value = r_fixed
        dut.height.value = h_fixed
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Get result
        result_fixed = dut.volume.value.integer
        result_float = from_q16_16(result_fixed)
        
        # Check with relative tolerance
        rel_tol = 0.001
        abs_tol = 0.5
        
        if math.isclose(result_float, expected, rel_tol=rel_tol, abs_tol=abs_tol):
            passed += 1
            print(f"✓ Test passed: r={r}, h={h}")
            print(f"  Expected: {expected:.6f}")
            print(f"  Got:      {result_float:.6f}")
            print(f"  Fixed-point: 0x{result_fixed:08X}")
        else:
            print(f"✗ Test failed: r={r}, h={h}")
            print(f"  Expected: {expected:.6f} (0x{to_q16_16(expected):08X})")
            print(f"  Got:      {result_float:.6f} (0x{result_fixed:08X})")
            print(f"  Difference: {abs(result_float - expected):.6f}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_cone_volume_boundary(dut):
    """Test cone volume with boundary values"""
    
    # Test with values near maximum safe range for Q16.16
    # Max value is about 65535.9999
    
    test_cases = [
        (100.0, 50.0, 52359.87755982989),  # r=100, h=50
        (1.5, 2.5, 5.890486225480862),     # Non-integer values
    ]
    
    passed = 0
    total = len(test_cases)
    
    for r, h, expected in test_cases:
        r_fixed = to_q16_16(r)
        h_fixed = to_q16_16(h)
        
        dut.radius.value = r_fixed
        dut.height.value = h_fixed
        
        await Timer(10, units='ns')
        
        result_fixed = dut.volume.value.integer
        result_float = from_q16_16(result_fixed)
        
        if math.isclose(result_float, expected, rel_tol=0.001):
            passed += 1
            print(f"✓ Boundary test passed: r={r}, h={h}")
        else:
            print(f"✗ Boundary test failed: r={r}, h={h}")
            print(f"  Expected: {expected:.6f}")
            print(f"  Got:      {result_float:.6f}")
    
    print(f"
{passed}/{total} boundary tests passed")
    assert passed == total
