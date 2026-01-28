import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 32
DATA_WIDTH = 5  # Bits for n and k (0-31)

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

def generate_expected_pattern(n, k):
    """Generate expected pattern in Python for verification."""
    if n > MAX_N:
        raise ValueError(f"n={n} exceeds MAX_N={MAX_N}")
    
    a = (n - k) // 2
    result = []
    for i in range(n):
        if a == 0:
            result.append(1)
        else:
            if (i % (a + 1)) == a:
                result.append(1)
            else:
                result.append(0)
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_minimal_unique_substring(dut):
    """Test the minimal_unique_substring module."""
    
    dut._log.info(f"Testing with MAX_N={MAX_N}")
    
    # Verify required signals exist
    if not (has_signal(dut, 'n') and has_signal(dut, 'k') and has_signal(dut, 'result')):
        raise TestFailure("Missing required signals: n, k, or result")
    
    # Define comprehensive test cases
    test_cases = [
        (1, 1, "Minimal case: n=k=1"),
        (2, 2, "Small n=k"),
        (3, 3, "Small n=k"),
        (3, 1, "n=3, k=1"),
        (4, 4, "n=k case: all ones"),
        (4, 2, "n=4, k=2"),
        (5, 3, "n>k case: periodic pattern"),
        (5, 1, "n=5, k=1"),
        (7, 3, "n>k case: longer string"),
        (8, 4, "Even case"),
        (9, 5, "Odd case"),
        (10, 2, "Larger n, small k"),
        (16, 16, "Power of 2 n=k"),
        (16, 4, "Power of 2 n>k"),
        (31, 31, "Max odd n=k"),
        (31, 1, "Max odd n, min k"),
        (32, 32, "Max even n=k"),
        (32, 2, "Max even n, min k"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description} (n={n}, k={k})")
        
        try:
            # Clamp values to width
            n_val = clamp_to_width(n, DATA_WIDTH)
            k_val = clamp_to_width(k, DATA_WIDTH)
            
            # Set inputs
            dut.n.value = n_val
            dut.k.value = k_val
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Verify result is defined
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            # Read result
            result_int = int(dut.result.value)
            
            # Generate expected pattern
            expected_bits = generate_expected_pattern(n, k)
            
            # Extract actual bits
            actual_bits = []
            for idx in range(n):
                bit = (result_int >> idx) & 1
                actual_bits.append(bit)
            
            # Compare
            if actual_bits != expected_bits:
                expected_str = ''.join(str(b) for b in expected_bits)
                actual_str = ''.join(str(b) for b in actual_bits)
                a_val = (n - k) // 2
                raise TestFailure(
                    f"Pattern mismatch:\n"
                    f"  Expected: {expected_str}\n"
                    f"  Actual:   {actual_str}\n"
                    f"  n={n}, k={k}, a={a_val}, period={a_val+1}"
                )
            
            # Log success
            pattern_str = ''.join(str(b) for b in expected_bits)
            dut._log.info(f"  PASS: pattern = {pattern_str}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            dut._log.error(f"  ERROR: Unexpected exception: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"Test Results: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")