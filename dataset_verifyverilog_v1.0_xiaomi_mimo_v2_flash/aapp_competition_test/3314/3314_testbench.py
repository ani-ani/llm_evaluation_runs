import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 2          # 2 bits per letter (A=0, B=1, C=2)
ARRAY_SIZE = 8          # 8 columns per wheel
RESULT_WIDTH = 5        # 5-bit result (including -1)
CLK_PERIOD_NS = 10

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if cocotb value is defined (not X or Z)."""
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

def letter_to_bits(c):
    """Convert letter to 2-bit value: A=0, B=1, C=2."""
    mapping = {'A': 0, 'B': 1, 'C': 2}
    return mapping[c]

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_wheel(dut, wheel_name, letters):
    """Write letters to wheel array."""
    # Try 2D array access
    try:
        wheel = getattr(dut, wheel_name)
        for i, c in enumerate(letters):
            wheel[i].value = clamp_to_width(letter_to_bits(c), DATA_WIDTH)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (wheel0_0, wheel0_1, ...)
    for i, c in enumerate(letters):
        port_name = f"{wheel_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(letter_to_bits(c), DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find port: {port_name}")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_wheel_rotations(dut):
    """Test the wheel rotations module."""
    
    # Log interface detection
    has_wheel0 = has_signal(dut, 'wheel0') or has_signal(dut, 'wheel0_0')
    has_result = has_signal(dut, 'result')
    
    if not has_wheel0 or not has_result:
        dut._log.error("Missing required signals: wheel0 and result")
        raise TestFailure("Missing required signals")
    
    # Test cases: (wheel0, wheel1, wheel2, expected_result, description)
    test_cases = [
        # Case 1: All same - impossible -> -1
        ("AAAAAAAA", "AAAAAAAA", "AAAAAAAA", 31, "All identical - impossible"),
        
        # Case 2: Already perfect - 0 rotations
        ("ABABABAB", "BCBCBCBC", "CACACACA", 0, "Already perfect"),
        
        # Case 3: Needs 2 rotations (example from problem)
        ("ABCABCAB", "ABCABCAB", "ABCABCAB", 2, "Needs 2 rotations"),
        
        # Case 4: Needs 3 rotations (example from problem)  
        ("ABBBAAAA", "BBBCCCBB", "CCCCAAAC", 3, "Needs 3 rotations"),
        
        # Case 5: Mixed case
        ("AABBCCAA", "BCCAAABB", "CCAABBCC", 1, "Mixed case"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (w0, w1, w2, expected, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        dut._log.info(f"  Wheel0: {w0}")
        dut._log.info(f"  Wheel1: {w1}")
        dut._log.info(f"  Wheel2: {w2}")
        
        try:
            # Write inputs
            await write_wheel(dut, 'wheel0', w0)
            await write_wheel(dut, 'wheel1', w1)
            await write_wheel(dut, 'wheel2', w2)
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read result
            result_sig = getattr(dut, 'result')
            if not is_value_defined(result_sig.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(result_sig.value)
            
            # Convert to signed for comparison
            if result >= 16:  # MSB set, negative
                result_signed = result - 32
            else:
                result_signed = result
            
            # Verify
            if result_signed != expected:
                raise TestFailure(f"Expected {expected}, got {result_signed} (raw: {result})")
            
            dut._log.info(f"  PASS: result = {result_signed}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")