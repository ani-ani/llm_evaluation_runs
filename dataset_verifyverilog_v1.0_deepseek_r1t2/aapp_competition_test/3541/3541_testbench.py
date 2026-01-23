import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 4
VAL_BITS = 3
TIMEOUT_MS = 1000

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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to signed range and return unsigned representation."""
    min_signed = -(1 << (bits - 1))
    max_signed = (1 << (bits - 1)) - 1
    clamped = max(min_signed, min(max_signed, value))
    return from_signed(clamped, bits)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=TIMEOUT_MS, timeout_unit="ms")
async def test_candy_splitter(dut):
    """Test the CandySplitter combinational module."""
    
    test_cases = [
        {
            'a': [-2, -1, 0, 1],
            'b': [2, 1, 0, -1],
            'expected': 'AAAA',
            'description': 'Symmetric values'
        },
        {
            'a': [2, 1, 0, 1],
            'b': [2, 1, 0, 1],
            'expected': 'BAAA',
            'description': 'Positive values'
        },
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test_case in enumerate(test_cases):
        a_vals = test_case['a']
        b_vals = test_case['b']
        expected = test_case['expected']
        description = test_case['description']
        
        cocotb.log.info(f"Test {test_idx + 1}: {description}")
        cocotb.log.info(f"  a = {a_vals}")
        cocotb.log.info(f"  b = {b_vals}")
        
        try:
            # Assign inputs individually
            for i in range(N):
                a_unsigned = clamp_to_width(a_vals[i], VAL_BITS)
                b_unsigned = clamp_to_width(b_vals[i], VAL_BITS)
                
                if has_signal(dut, f'a_{i}'):
                    getattr(dut, f'a_{i}').value = a_unsigned
                else:
                    raise TestFailure(f"Signal a_{i} not found")
                    
                if has_signal(dut, f'b_{i}'):
                    getattr(dut, f'b_{i}').value = b_unsigned
                else:
                    raise TestFailure(f"Signal b_{i} not found")
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read output
            if not has_signal(dut, 'assignment'):
                raise TestFailure("Output signal 'assignment' not found")
            
            assignment_signal = dut.assignment.value
            if not is_value_defined(assignment_signal):
                raise TestFailure("Assignment output is undefined (X/Z)")
            
            assignment = int(assignment_signal)
            
            # Convert to string (candy 0 is assignment[0])
            result_str = ""
            for i in range(N):
                if (assignment >> i) & 1:
                    result_str += 'A'
                else:
                    result_str += 'B'
            
            cocotb.log.info(f"  Result: {result_str}")
            cocotb.log.info(f"  Expected: {expected}")
            
            if result_str != expected:
                raise TestFailure(f"Expected '{expected}', got '{result_str}'")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")