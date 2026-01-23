import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def pack_string(s, max_len=16):
    """Pack string into 128-bit integer (LSB first)."""
    packed = 0
    for i, c in enumerate(s[:max_len]):
        packed |= ord(c) << (8 * i)
    return packed

# ============================================================================
# TEST CASES
# ============================================================================
@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_puppy_standardization(dut):
    """Test puppy standardization module."""
    
    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("aabddc", 1, "Example 1: has duplicates"),
        ("abc", 0, "Example 2: no duplicates"),
        ("jjj", 1, "Example 3: all same"),
        ("d", 1, "Single puppy"),
        ("az", 0, "Two different"),
        ("aa", 1, "Two same"),
        ("aba", 1, "Three with duplicate"),
        ("abcdee", 1, "Longer with duplicate"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        length = len(test_str)
        # Pack string and set inputs
        dut.string.value = pack_string(test_str)
        dut.length.value = length
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Check result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
            
        result = int(dut.result.value)
        
        if result != expected:
            dut._log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")