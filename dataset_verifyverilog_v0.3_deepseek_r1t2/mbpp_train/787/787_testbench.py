import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
CHAR_WIDTH = 8
MAX_STRING_LEN = 16
INPUT_WIDTH = CHAR_WIDTH * MAX_STRING_LEN  # 128 bits

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_string(text):
    """Pack a Python string into the 128-bit input format."""
    # Truncate to max length
    text = text[:MAX_STRING_LEN]
    packed = 0
    for i, char in enumerate(text):
        ascii_val = ord(char)
        packed |= (ascii_val << (i * CHAR_WIDTH))
    return packed

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_text_match_three(dut):
    """Test the text pattern matching module."""
    
    # Configure based on actual DUT signals
    DATA_WIDTH = 128
    LEN_WIDTH = 4
    
    # Define test cases: (string, expected_match, description)
    test_cases = [
        ("ac", False, "Short string without pattern"),
        ("dc", False, "No 'a' followed by 'bbb'"),
        ("abbbba", True, "Contains 'abbb' at start"),
        ("caacabbbba", True, "Contains 'abbb' in middle"),
        ("abbb", True, "Exact pattern at start"),
        ("a", False, "Only 'a', no 'bbb'"),
        ("ab", False, "'a' and 'b', need 3 b's"),
        ("abb", False, "'a' and 2 b's, need 3 b's"),
        ("bbbb", False, "Three b's but no 'a' before"),
        ("ababbb", True, "Pattern at position 2"),
        ("", False, "Empty string"),
        ("cabbb", True, "Pattern at end"),
        ("abbbabbb", True, "Multiple patterns"),
        ("bbbba", False, "b's before a, not a before b's"),
        ("aaabbb", False, "Two a's then b's - first a needs 3 b's"),
    ]
    
    passed = 0
    failed = 0
    
    dut._log.info(f"Starting test with {len(test_cases)} test cases")
    
    for i, (test_string, expected, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        dut._log.info(f"  Input string: '{test_string}'")
        dut._log.info(f"  Expected match: {expected}")
        
        try:
            # Pack the string into the input
            packed_value = pack_string(test_string)
            
            # Assign to DUT - handle different interface styles
            if has_signal(dut, 'text_in'):
                dut.text_in.value = packed_value
            elif has_signal(dut, 'text_in') and hasattr(dut.text_in, 'value'):
                dut.text_in.value = packed_value
            else:
                # Try to assign as individual bits if needed
                # For this test, we assume text_in exists
                if hasattr(dut, 'text_in'):
                    dut.text_in.value = packed_value
            
            # Set length
            if has_signal(dut, 'length'):
                dut.length.value = len(test_string)
            
            # Wait for combinational logic to settle
            await Timer(50, units='ns')
            
            # Read result
            if not has_signal(dut, 'match'):
                raise TestFailure("Signal 'match' not found in DUT")
            
            if not is_value_defined(dut.match.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = bool(int(dut.match.value))
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAILED: {e}")
            failed += 1
        except Exception as e:
            dut._log.error(f"  ERROR: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    dut._log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
