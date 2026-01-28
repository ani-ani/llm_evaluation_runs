import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 4

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_odd_equivalent(dut):
    """Test odd_Equivalent module with various test cases."""
    
    cocotb.log.info("Starting odd_Equivalent test")
    
    # Test cases: (input_value, expected_count, description)
    # All inputs are 8-bit binary values
    test_cases = [
        (0b01100110, 4, "Test 1: 01100110 has 4 ones"),
        (0b00011011, 4, "Test 2: 00011011 has 4 ones"),
        (0b00001010, 2, "Test 3: 00001010 has 2 ones"),
        (0b00000000, 0, "Test 4: All zeros"),
        (0b11111111, 8, "Test 5: All ones"),
        (0b00000001, 1, "Test 6: Single one at LSB"),
        (0b10000000, 1, "Test 7: Single one at MSB"),
        (0b00010001, 2, "Test 8: Two ones spread out"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set input - handle different port names
            if has_signal(dut, 'binary_string'):
                dut.binary_string.value = input_val
            elif has_signal(dut, 'str'):
                dut.str.value = input_val
            elif has_signal(dut, 'data_in'):
                dut.data_in.value = input_val
            else:
                raise TestFailure("Cannot find binary string input port")
            
            # Wait for combinational logic to settle
            await Timer(50, units='ns')
            
            # Read output - handle different port names
            output_signal = None
            for port_name in ['count', 'result', 'output']:
                if has_signal(dut, port_name):
                    output_signal = getattr(dut, port_name)
                    break
            
            if output_signal is None:
                raise TestFailure("Cannot find count output port")
            
            if not is_value_defined(output_signal.value):
                raise TestFailure(f"Output count is undefined (X/Z)")
            
            result = int(output_signal.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: count = {result} (expected {expected})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
