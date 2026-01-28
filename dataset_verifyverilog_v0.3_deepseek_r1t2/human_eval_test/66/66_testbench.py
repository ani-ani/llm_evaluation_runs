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

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_digit_sum(dut):
    """Test digit_sum module with various test cases"""
    
    # Helper function to convert string to ASCII values
    def string_to_ascii(s):
        """Convert string to list of 8 ASCII values (8-char max, padded with 0)"""
        ascii_vals = [ord(c) for c in s]
        # Pad to 8 characters with zeros
        while len(ascii_vals) < 8:
            ascii_vals.append(0)
        # Truncate to 8 characters
        return ascii_vals[:8]
    
    # Test cases: (input_string, expected_sum)
    test_cases = [
        ("", 0),
        ("abAB", 131),
        ("abcCd", 67),
        ("helloE", 69),
        ("woArBld", 131),
        ("aAaaaXa", 153),
        (" How are yOu?", 151),
        ("You arE Very Smart", 327),
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases for digit_sum module")
    
    for i, (input_str, expected) in enumerate(test_cases):
        # Convert input string to ASCII values
        ascii_vals = string_to_ascii(input_str)
        
        # Display test info
        dut._log.info(f"Test {i+1}: Input='{input_str}' (ASCII: {ascii_vals})")
        dut._log.info(f"  Expected result: {expected}")
        
        # Assign values to dut inputs
        # Array interface: dut.char_0, dut.char_1, ... dut.char_7
        for j in range(8):
            input_signal = getattr(dut, f'char_{j}')
            input_signal.value = ascii_vals[j]
        
        # Wait for combinational logic to propagate
        await Timer(50, units='ns')
        
        # Check if output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
        
        # Read result
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            dut._log.info(f"  Result: {result} [PASS]")
            passed += 1
        else:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
    
    # Summary
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed == total:
        dut._log.info("All tests completed successfully!")
    else:
        raise TestFailure(f"Only {passed}/{total} tests passed")