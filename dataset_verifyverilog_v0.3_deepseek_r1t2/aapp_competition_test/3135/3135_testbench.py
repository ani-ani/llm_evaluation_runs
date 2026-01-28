import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

DATA_WIDTH = 8
ARRAY_SIZE = 9   # digits 0..8

def digit_to_char(d):
    if d == 1:  # 2'b01
        return '+'
    elif d == 2: # 2'b10
        return '-'
    else:
        return '0'

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_signed_binary_representor(dut):
    """Test the signed binary representation module."""

    # No clock needed (combinational)
    
    # Define test cases: (num, expected_string)
    test_cases = [
        (1, '+'),
        (3, '++'),
        (15, '+000-'),
        (16, '+0000'),
        (23, '++00-'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num, expected) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: num={num}, expected={expected}')
        
        # Set input
        dut.num.value = num
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        
        # Read len_out
        len_out = safe_int(dut.len_out.value, 0)
        
        # Build result string from digits
        result_chars = []
        for idx in range(ARRAY_SIZE):
            if idx < len_out:
                sig = getattr(dut, f'digit_{idx}')
                if is_value_defined(sig.value):
                    digit_val = int(sig.value)
                    result_chars.append(digit_to_char(digit_val))
                else:
                    result_chars.append('?')
        
        result = ''.join(result_chars)
        
        # Compare
        if result != expected:
            dut._log.error(f'FAIL: Expected "{expected}", got "{result}"')
            failed += 1
        else:
            dut._log.info(f'  PASS: got "{result}"')
            passed += 1
    
    # Summary
    dut._log.info(f'{"="*50}')
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')
