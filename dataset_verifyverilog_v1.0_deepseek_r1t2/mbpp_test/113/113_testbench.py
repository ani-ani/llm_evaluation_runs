import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def pack_string(s, max_len=16):
    """Pack string into 128-bit integer (ASCII values)."""
    packed = 0
    for i, char in enumerate(s[:max_len]):
        packed |= (ord(char) << (8 * i))
    return packed

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_check_integer(dut):
    """Test the string_is_integer module."""
    
    # Test cases: (string, expected_result)
    test_cases = [
        ("python", 0),  # Test 1
        ("1", 1),       # Test 2
        ("12345", 1),   # Test 3
        ("", 0),        # Empty string
        ("+123", 1),    # Positive sign
        ("-123", 1),    # Negative sign
        ("++123", 0),   # Double sign
        ("123a", 0),    # Mixed
        ("-", 0),       # Only sign
        ("+", 0),       # Only sign
        ("-0", 1),      # Zero with sign
    ]
    
    for text, expected in test_cases:
        dut._log.info(f"Testing: '{text}' -> Expected: {expected}")
        
        # Pack input
        packed_input = pack_string(text)
        length = len(text)
        
        # Drive inputs
        dut.char_array.value = packed_input
        dut.length.value = length
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read output
        if not is_value_defined(dut.is_integer.value):
            raise TestFailure(f"Output is undefined for input '{text}'")
            
        result = int(dut.is_integer.value)
        
        if result != expected:
            raise TestFailure(f"Input '{text}': expected {expected}, got {result}")
        
        dut._log.info(f"  PASS")
