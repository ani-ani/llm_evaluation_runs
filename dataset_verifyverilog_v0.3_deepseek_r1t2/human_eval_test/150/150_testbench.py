import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

# Test cases: (n, x, y, expected_result, description)
test_cases = [
    (7, 34, 12, 34, "7 is prime"),
    (15, 8, 5, 5, "15 is not prime"),
    (3, 33, 5212, 33, "3 is prime"),
    (1259, 3, 52, 3, "1259 is prime"),
    (7919, -1, 12, 255, "7919 is prime (but n truncated to 8-bit)"),
    (3609, 1245, 583, 583, "3609 is not prime (truncated)"),
    (91, 56, 129, 129, "91 is not prime"),
    (6, 34, 1234, 1234, "6 is not prime"),
    (1, 2, 0, 0, "1 is not prime"),
    (2, 2, 0, 2, "2 is prime"),
    (0, 5, 10, 10, "0 is not prime"),
    (4, 100, 200, 200, "4 is not prime"),
    (13, 50, 60, 50, "13 is prime"),
    (17, 70, 80, 70, "17 is prime"),
    (255, 99, 88, 88, "255 is not prime"),
    (251, 66, 77, 66, "251 is prime"),
]

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_x_or_y(dut):
    """Test x_or_y module with various prime and non-prime inputs."""
    
    dut._log.info("Starting x_or_y tests")
    passed = 0
    failed = 0
    
    for n_val, x_val, y_val, expected, description in test_cases:
        # Handle signed values for x and y (8-bit signed range: -128 to 127)
        # Map negative values to their 8-bit unsigned representation
        x_unsigned = x_val & 0xFF
        y_unsigned = y_val & 0xFF
        
        # Assign inputs
        dut.n.value = n_val
        dut.x.value = x_unsigned
        dut.y.value = y_unsigned
        
        # Wait for combinational logic to propagate
        await Timer(100, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test failed: {description} - Output is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # For 7919 test case, n is truncated to 8-bit (7919 % 256 = 239)
        # 239 is prime, so result should be x (255 in 8-bit)
        if description == "7919 is prime (but n truncated to 8-bit)":
            actual_expected = 255
        else:
            actual_expected = expected
        
        if result == actual_expected:
            dut._log.info(f"PASS: {description} (n={n_val}, x={x_val}, y={y_val}) => {result}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {description} (n={n_val}, x={x_val}, y={y_val})")
            dut._log.error(f"  Expected: {actual_expected}, Got: {result}")
            failed += 1
    
    total = passed + failed
    dut._log.info(f"\nTest Summary: {passed}/{total} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {total} tests failed")