import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N_WIDTH = 8
RESULT_WIDTH = 16

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def compute_tetrahedral(n):
    """Compute tetrahedral number in Python for verification."""
    return (n * (n + 1) * (n + 2)) // 6

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tetrahedral_number(dut):
    """Test tetrahedral number calculation."""
    
    # Log configuration
    dut._log.info(f"Testing tetrahedral number calculation")
    dut._log.info(f"Input width: {N_WIDTH} bits, Output width: {RESULT_WIDTH} bits")
    
    # Test cases from problem
    test_cases = [
        (5, 35, "T(5) = 5*6*7/6 = 35"),
        (6, 56, "T(6) = 6*7*8/6 = 56"),
        (7, 84, "T(7) = 7*8*9/6 = 84"),
    ]
    
    # Additional test cases for completeness
    additional_cases = [
        (1, 1, "T(1) = 1"),
        (2, 4, "T(2) = 4"),
        (3, 10, "T(3) = 10"),
        (10, 220, "T(10) = 220"),
        (0, 0, "T(0) = 0"),
    ]
    
    all_cases = test_cases + additional_cases
    
    passed = 0
    failed = 0
    
    for i, (n_input, expected, description) in enumerate(all_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Clamp input to valid range
            n_clamped = clamp_to_width(n_input, N_WIDTH)
            
            # Assign input
            if has_signal(dut, 'n'):
                dut.n.value = n_clamped
            else:
                raise TestFailure("Input signal 'n' not found")
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Output signal 'result' not found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z) for n={n_input}")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result} for n={n_input}")
            
            dut._log.info(f"  PASS: n={n_input} -> result={result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")