import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_fixed_point(value):
    """Convert float to Q16.16 fixed-point representation."""
    return int(value * 65536)

def from_fixed_point(value):
    """Convert Q16.16 fixed-point to float."""
    return value / 65536.0

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_triangle_area_basic(dut):
    """Test triangle_area with basic test cases."""
    
    test_cases = [
        (5.0, 3.0, 7.5),   # Original test case
        (2.0, 2.0, 2.0),   # Edge case
        (10.0, 8.0, 40.0), # Larger values
        (1.0, 1.0, 0.5),   # Small values
        (0.0, 5.0, 0.0),   # Zero base
        (5.0, 0.0, 0.0),   # Zero height
        (1.5, 4.0, 3.0),   # Non-integer base
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (base_fp, height_fp, expected_fp) in enumerate(test_cases):
        # Convert to fixed-point
        base_val = to_fixed_point(base_fp)
        height_val = to_fixed_point(height_fp)
        expected = to_fixed_point(expected_fp)
        
        # Apply inputs
        dut.base.value = base_val
        dut.height.value = height_val
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Check output is defined
        if not is_value_defined(dut.area.value):
            raise TestFailure(f"Test {i}: Output area is undefined (X/Z)")
        
        # Read result
        result = int(dut.area.value)
        
        # Allow small rounding error (±1 in fixed-point)
        if abs(result - expected) <= 1:
            passed += 1
            dut._log.info(f"Test {i}: base={base_fp}, height={height_fp} -> area={from_fixed_point(result):.4f} (expected {expected_fp:.4f}) [PASS]")
        else:
            raise TestFailure(f"Test {i}: base={base_fp}, height={height_fp} -> area={from_fixed_point(result):.4f}, expected {expected_fp:.4f}")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_triangle_area_random(dut):
    """Test with random values."""
    
    random.seed(42)
    passed = 0
    total = 20
    
    for i in range(total):
        # Generate random base and height (0.0 to 100.0)
        base_fp = random.uniform(0.0, 100.0)
        height_fp = random.uniform(0.0, 100.0)
        expected_fp = 0.5 * base_fp * height_fp
        
        base_val = to_fixed_point(base_fp)
        height_val = to_fixed_point(height_fp)
        expected = to_fixed_point(expected_fp)
        
        dut.base.value = base_val
        dut.height.value = height_val
        
        await Timer(10, units='ns')
        
        if not is_value_defined(dut.area.value):
            raise TestFailure(f"Random test {i}: Output is undefined")
        
        result = int(dut.area.value)
        
        # Allow rounding tolerance
        if abs(result - expected) <= 1:
            passed += 1
        else:
            raise TestFailure(f"Random test {i}: got {from_fixed_point(result):.4f}, expected {from_fixed_point(expected):.4f}")
    
    dut._log.info(f"\nRandom tests: {passed}/{total} tests passed")