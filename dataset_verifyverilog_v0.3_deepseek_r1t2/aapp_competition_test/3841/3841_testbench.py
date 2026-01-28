import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
DATA_WIDTH = 60
K_WIDTH = 12
RESULT_WIDTH = 12
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS

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
# COMPUTE EXPECTED COEFFICIENTS

def compute_coefficients(p, k):
    """Compute expected coefficients using negative base conversion."""
    coeffs = []
    n = p
    while n != 0:
        remainder = n % k
        n = n // k
        if remainder < 0:
            remainder += k
            n += 1
        n = -n
        coeffs.append(remainder)
    return coeffs

# ============================================================================
# MAIN TEST

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_polynomial(dut):
    """Test the find_polynomial module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.p_in.value = 0
    dut.k_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (46, 2),
        (2018, 214),
        (4, 2),
        (5, 2),
        (10, 3),
        (250, 1958),
        (1000000000000000000, 2000),
        (1, 2),
        (2, 2),
        (3, 2),
        (6, 2),
        (7, 2),
        (8, 2),
        (9, 2),
        (10, 2),
        (1, 3),
        (2, 3),
        (3, 3),
        (4, 3),
        (5, 3),
        (6, 3),
        (7, 3),
        (8, 3),
        (9, 3),
        (462, 2),
        (462, 3),
        (2018, 4),
        (20180214, 5),
        (1317, 221),
        (1314, 520),
        (1562, 862),
        (6666666666666666, 3),
        (252525252525252525, 252),
        (271828182845904523, 536),
        (314159265358979323, 846),
        (393939393939393939, 393),
        (233333333333333333, 2000),
        (998244353998244353, 2000),
        (1000000000000000000, 2),
        (1000000000000000000, 3),
    ]
    
    passed = 0
    failed = 0
    
    for i, (p, k) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: p={p}, k={k}")
        
        # Compute expected coefficients
        expected = compute_coefficients(p, k)
        
        # Clamp inputs to fit in DUT width
        p_clamped = clamp_to_width(p, DATA_WIDTH)
        k_clamped = clamp_to_width(k, K_WIDTH)
        
        # Set inputs
        dut.p_in.value = p_clamped
        dut.k_in.value = k_clamped
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect coefficients
        coefficients = []
        cycles = 0
        done = False
        
        while not done and cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
            
            # Check valid
            if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                coeff_val = int(dut.coeff.value)
                coefficients.append(coeff_val)
            
            # Check done
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
        
        # Verify
        if not done:
            cocotb.log.error(f"Test {i+1}: Timeout after {MAX_CYCLES} cycles")
            failed += 1
        elif coefficients != expected:
            cocotb.log.error(f"Test {i+1}: Expected {expected}, got {coefficients}")
            failed += 1
        else:
            cocotb.log.info(f"Test {i+1}: PASS - coefficients: {coefficients}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
