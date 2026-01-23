import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32          # Q16.16 format
FRAC_BITS = 16
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def float_to_q16_16(f):
    """Convert float to Q16.16 integer representation."""
    return int(f * (1 << FRAC_BITS))

def q16_16_to_float(q):
    """Convert Q16.16 integer to float."""
    return q / (1 << FRAC_BITS)

# ============================================================================
# TEST CASES
# ============================================================================

# Test cases: (s_float, r_float, n, z, expected_output, description)
# Using the examples and additional edge cases
TEST_CASES = [
    # Example cases
    (3.0, 1.0, 4, 40, 3, "Example 1: area constraint limits to 3"),
    (3.0, 1.0, 4, 100, 4, "Example 2: all 4 fit"),
    
    # Edge cases
    (5.0, 1.0, 7, 100, 7, "Large sandwich, all fit"),
    (2.0, 1.0, 7, 100, 2, "Small sandwich, packing limits to 2"),
    (3.0, 1.0, 7, 30, 2, "Low area percentage"),
    (1.0, 1.0, 1, 100, 1, "Equal radii"),
    (1.0, 0.5, 1, 100, 1, "Small pickle"),
    (1.0, 0.5, 4, 100, 4, "4 small pickles fit"),
    (3.0, 2.0, 7, 100, 1, "Large pickle, packing limits to 1"),
    (10.0, 0.5, 7, 100, 7, "Maximum case"),
    (10.0, 0.5, 7, 1, 0, "Very low area percentage"),
]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pickle_sandwich(dut):
    """Test the pickle sandwich module."""
    
    # Initialize
    dut.s.value = 0
    dut.r.value = 0
    dut.n.value = 0
    dut.z.value = 0
    
    # Wait for initial propagation
    await Timer(100, units='ns')
    
    passed = 0
    failed = 0
    
    for i, (s_float, r_float, n, z, expected, description) in enumerate(TEST_CASES):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: s={s_float}, r={r_float}, n={n}, z={z}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Convert to Q16.16
            s_q16 = float_to_q16_16(s_float)
            r_q16 = float_to_q16_16(r_float)
            
            # Assign inputs
            dut.s.value = s_q16
            dut.r.value = r_q16
            dut.n.value = n
            dut.z.value = z
            
            # Wait for combinational logic to settle
            await Timer(200, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TESTS FOR PACKING CONSTRAINT
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_packing_constraints(dut):
    """Test packing constraint logic with various s/r ratios."""
    
    # Test cases for packing: (s_float, r_float, n, z, expected, description)
    packing_tests = [
        # s/r ratio < 1: 0 pickles
        (0.9, 1.0, 7, 100, 0, "s/r < 1: no pickle fits"),
        
        # 1 <= s/r < 2: 1 pickle
        (1.0, 1.0, 7, 100, 1, "s/r = 1: exactly 1"),
        (1.5, 1.0, 7, 100, 1, "s/r = 1.5: only 1"),
        
        # 2 <= s/r < 2.1547: 2 pickles
        (2.0, 1.0, 7, 100, 2, "s/r = 2: exactly 2"),
        (2.1, 1.0, 7, 100, 2, "s/r = 2.1: still 2"),
        
        # 2.1547 <= s/r < 2.4142: 3 pickles
        (2.2, 1.0, 7, 100, 3, "s/r = 2.2: can fit 3"),
        
        # 2.4142 <= s/r < 2.7013: 4 pickles
        (2.5, 1.0, 7, 100, 4, "s/r = 2.5: can fit 4"),
        
        # 2.7013 <= s/r < 3: 5 pickles
        (2.8, 1.0, 7, 100, 5, "s/r = 2.8: can fit 5"),
        
        # s/r >= 3: 7 pickles (max)
        (3.0, 1.0, 7, 100, 7, "s/r = 3: can fit 7"),
        (4.0, 1.0, 7, 100, 7, "s/r = 4: can fit 7"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s_float, r_float, n, z, expected, description) in enumerate(packing_tests):
        cocotb.log.info(f"Packing Test {i+1}: {description}")
        
        try:
            s_q16 = float_to_q16_16(s_float)
            r_q16 = float_to_q16_16(r_float)
            
            dut.s.value = s_q16
            dut.r.value = r_q16
            dut.n.value = n
            dut.z.value = z
            
            await Timer(200, units='ns')
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nPacking Summary: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} packing tests failed")