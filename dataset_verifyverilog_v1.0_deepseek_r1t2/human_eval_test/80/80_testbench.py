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

def pack_string(string):
    """Pack a string into array of character values."""
    return [ord(c) for c in string]

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_is_happy(dut):
    """Test the is_happy module with various string inputs."""
    
    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("a", False, "a"),
        ("aa", False, "aa"),
        ("abcd", True, "abcd"),
        ("aabb", False, "aabb"),
        ("adb", True, "adb"),
        ("xyy", False, "xyy"),
        ("iopaxpoi", True, "iopaxpoi"),
        ("iopaxioi", False, "iopaxioi"),
        ("", False, "empty string"),
        ("abc", True, "abc - exactly 3, all distinct"),
        ("aaa", False, "aaa - exactly 3, all same"),
        ("ab", False, "ab - only 2 chars"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_str, expected, desc in test_cases:
        # Prepare input
        chars = pack_string(test_str)
        length = len(chars)
        
        # Set inputs
        dut.length.value = length
        
        # Set character inputs (0-7)
        for i in range(8):
            if i < length:
                dut.char_0.value = chars[0] if i == 0 else dut.char_0.value
                dut.char_1.value = chars[1] if i == 1 else dut.char_1.value
                dut.char_2.value = chars[2] if i == 2 else dut.char_2.value
                dut.char_3.value = chars[3] if i == 3 else dut.char_3.value
                dut.char_4.value = chars[4] if i == 4 else dut.char_4.value
                dut.char_5.value = chars[5] if i == 5 else dut.char_5.value
                dut.char_6.value = chars[6] if i == 6 else dut.char_6.value
                dut.char_7.value = chars[7] if i == 7 else dut.char_7.value
            else:
                # Set unused chars to 0
                if i == 0: dut.char_0.value = 0
                if i == 1: dut.char_1.value = 0
                if i == 2: dut.char_2.value = 0
                if i == 3: dut.char_3.value = 0
                if i == 4: dut.char_4.value = 0
                if i == 5: dut.char_5.value = 0
                if i == 6: dut.char_6.value = 0
                if i == 7: dut.char_7.value = 0
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.is_happy.value):
            raise TestFailure(f"Test '{desc}': Output is_happy is undefined (X/Z)")
        
        # Read result
        result = int(dut.is_happy.value)
        
        # Verify
        if result != (1 if expected else 0):
            raise TestFailure(f"Test '{desc}': expected {1 if expected else 0}, got {result}")
        
        dut._log.info(f"Test '{desc}': PASSED (input='{test_str}', result={result})")
        passed += 1
    
    dut._log.info(f"\nSUMMARY: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Failed {total - passed} test(s)")