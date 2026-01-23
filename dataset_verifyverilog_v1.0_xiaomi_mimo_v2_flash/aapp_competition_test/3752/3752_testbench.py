import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def fixed_to_float(fixed_val, frac_bits=16):
    """Convert Q16.16 fixed-point to float."""
    return fixed_val / (1 << frac_bits)

# ============================================================================
# TEST CASES - SCALED DOWN FOR 16-BIT INPUTS
# ============================================================================

# Original test cases adapted to 16-bit range
# Format: (k, d, t, expected_float)
test_cases = [
    (3, 2, 6, 6.5),
    (4, 2, 20, 20.0),
    (8, 10, 9, 10.0),
    (43, 50, 140, 150.5),
    (251, 79, 76, 76.0),
    (892, 67, 1000, 1023.0),
    (1000, 1000, 1000, 1000.0),
    (87, 4, 1000, 1005.5),
    (2, 4, 18, 24.0),
    (3, 5, 127, 158.0),
    (330, 167, 15, 15.0),
    (387, 43, 650, 650.0),
    (1, 314, 824, 1642),
    (2, 4, 18, 24.0),
    (3, 5, 127, 158.0),
    (3260, 4439, 6837, 7426.5),
    (3950, 7386, 195, 195.0),
]

# Filter test cases to fit within 16-bit range
valid_test_cases = []
for k, d, t, expected in test_cases:
    if k <= 65535 and d <= 65535 and t <= 65535:
        valid_test_cases.append((k, d, t, expected))

if len(valid_test_cases) == 0:
    # Use minimal test cases if no valid ones
    valid_test_cases = [(3, 2, 6, 6.5), (4, 2, 20, 20.0)]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cook_time(dut):
    """Test the cook_time module."""
    
    cocotb.log.info(f"Testing with {len(valid_test_cases)} test cases")
    
    passed = 0
    failed = 0
    
    for i, (k, d, t, expected) in enumerate(valid_test_cases):
        cocotb.log.info(f"\nTest {i+1}: k={k}, d={d}, t={t} -> expected {expected}")
        
        try:
            # Clamp values to 16-bit
            k_val = clamp_to_width(k, 16)
            d_val = clamp_to_width(d, 16)
            t_val = clamp_to_width(t, 16)
            
            # Set inputs
            dut.k.value = k_val
            dut.d.value = d_val
            dut.t.value = t_val
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read output
            if not is_value_defined(dut.total_time.value):
                raise TestFailure(f"Output is undefined (X/Z)")
            
            result_fixed = int(dut.total_time.value)
            result_float = fixed_to_float(result_fixed, 16)
            
            # Allow small floating-point error
            error = abs(result_float - expected) / max(1.0, expected)
            
            if error > 1e-9:
                raise TestFailure(f"Expected {expected}, got {result_float} (error={error:.2e})")
            
            cocotb.log.info(f"  PASS: result = {result_float:.10f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")