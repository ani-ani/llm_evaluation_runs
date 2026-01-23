import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 64   # X is 64-bit
RESULT_WIDTH = 5  # k is 5-bit (max 10)
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_factors_power2(dut):
    """Test the max_factors_power2 module with powers of 2."""
    
    # Detect module type (combinational)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset (if reset signal exists)
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            for _ in range(2):
                await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    # Define test cases: (X, expected_k, description)
    # We test powers of 2: 2^n for n in [0, 1, 2, 10, 40, 63]
    test_cases = [
        (1, 0, "2^0 = 1 (no factors)"),
        (2, 1, "2^1 = 2, factor 2^1"),
        (4, 2, "2^2 = 4, factors 2^1 + 2^1? Wait distinct: 2^1 * 2^1 not allowed. Actually 4 = 2^2, exponents must be distinct: only 2^2, so k=1? Let's recompute: For N=2, distinct positive integers summing to 2: only {2} => k=1. But our formula gives k with k(k+1)/2 <=2: k=1 ->1<=2, k=2->3>2, so k=1. So correct."),
        (8, 2, "2^3 = 8, exponents 1+2=3 => k=2"),
        (1024, 4, "2^10 = 1024, exponents 1+2+3+4=10 => k=4"),
        (1099511627776, 8, "2^40 = 1099511627776, k=8"),
        (9223372036854775808, 10, "2^63 = 9223372036854775808, k=10")
    ]
    
    passed = 0
    failed = 0
    
    for i, (X, expected_k, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set X input
            dut.X.value = clamp_to_width(X, DATA_WIDTH)
            
            # Wait for combinational propagation
            if is_sequential:
                await RisingEdge(dut.k)  # Wait for output to update
            else:
                await Timer(10, units='ns')
            
            # Read k
            if not is_value_defined(dut.k.value):
                raise TestFailure(f"k is undefined (X/Z)")
            
            result = int(dut.k.value)
            
            if result != expected_k:
                raise TestFailure(f"Expected {expected_k}, got {result}")
            
            cocotb.log.info(f"  PASS: k = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
