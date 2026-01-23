import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to convert Q16.16 to integer for verification
def to_q1616(value):
    """Convert float to Q16.16 integer representation"""
    return int(value * 65536)

# Helper function to convert Q16.16 back to float for checking
def from_q1616(value):
    """Convert Q16.16 integer to float"""
    return value / 65536.0

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_truncate_number(dut):
    """Test truncation of fractional parts from fixed-point numbers"""
    
    # Test cases: (input_float, expected_float)
    # These match the Python problem requirements
    test_cases = [
        (3.5, 0.5),
        (1.33, 0.33),
        (123.456, 0.456),
        (0.0, 0.0),      # Edge case: zero
        (1.0, 0.0),      # Edge case: integer only
        (0.125, 0.125),  # Edge case: power of 2 fraction
    ]
    
    dut._log.info("Starting truncate_number tests...")
    
    passed = 0
    failed = 0
    
    for i, (input_val, expected_val) in enumerate(test_cases):
        # Convert input to Q16.16 format
        input_q1616 = to_q1616(input_val)
        
        # Apply input to DUT
        dut.number.value = input_q1616
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Check if output is defined
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i}: Output is undefined (X/Z)")
            failed += 1
            continue
        
        # Read result
        result_q1616 = int(dut.result.value)
        result_float = from_q1616(result_q1616)
        
        # Calculate expected Q16.16 value
        expected_q1616 = to_q1616(expected_val)
        
        # Check result with tolerance for floating point imprecision
        # In Q16.16, we allow small rounding differences
        tolerance = 1  # 1/65536 = 0.000015, which is ~1.5e-5
        
        if abs(result_q1616 - expected_q1616) <= tolerance:
            dut._log.info(f"Test {i}: PASSED - Input: {input_val} -> Output: {result_float:.6f} (Expected: {expected_val:.6f})")
            passed += 1
        else:
            dut._log.error(f"Test {i}: FAILED - Input: {input_val}")
            dut._log.error(f"  Got: {result_float:.6f} (0x{result_q1616:08X})")
            dut._log.error(f"  Expected: {expected_val:.6f} (0x{expected_q1616:08X})")
            failed += 1
    
    # Summary
    total = passed + failed
    dut._log.info(f"\nTest Summary: {passed}/{total} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {total} tests failed")