import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
RESULT_WIDTH = 8

# Helper functions
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def digit_distance_nums_py(n1, n2):
    """Reference Python implementation."""
    return sum(map(int, str(abs(n1 - n2))))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_digit_distance(dut):
    """Test digit distance computation."""
    
    # Test cases: (n1, n2, expected_result, description)
    test_cases = [
        (1, 2, 1, "Simple single digit"),
        (23, 56, 6, "Two digits"),
        (123, 256, 7, "Three digits"),
        (0, 0, 0, "Zero case"),
        (65535, 0, 30, "Max 16-bit value (65535 -> sum 30)"),
        (9999, 0, 36, "All nines (9999 -> sum 36)"),
        (1000, 1, 9, "Powers of 10"),
        (500, 450, 10, "Small difference"),
        (12345, 54321, 28, "Larger numbers"),
        (65535, 65535, 0, "Same numbers"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n1, n2, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: n1={n1}, n2={n2}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Clamp values to 16-bit
            n1_val = clamp_to_width(n1, DATA_WIDTH)
            n2_val = clamp_to_width(n2, DATA_WIDTH)
            
            # Assign inputs
            dut.n1.value = n1_val
            dut.n2.value = n2_val
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            # Also verify against Python reference
            py_result = digit_distance_nums_py(n1_val, n2_val)
            if result != py_result:
                raise TestFailure(f"Mismatch with Python ref: Python={py_result}, HDL={result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
