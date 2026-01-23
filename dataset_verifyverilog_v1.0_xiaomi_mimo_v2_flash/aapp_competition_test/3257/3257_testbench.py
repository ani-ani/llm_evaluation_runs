import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32          # Bit width for inputs/output
Q = 16                   # Fractional bits for Q16.16
SCALE = 1 << Q           # 65536
CLK_PERIOD_NS = 10
MAX_CYCLES = 200         # Max cycles to wait for done

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
# FIXED-POINT CONVERSION
# ============================================================================

def float_to_q1616(f):
    """Convert Python float to Q16.16 integer."""
    return int(round(f * SCALE))

def q1616_to_float(q):
    """Convert Q16.16 integer to Python float."""
    return q / SCALE

# ============================================================================
# EXPECTED VALUE COMPUTATION (using floating-point)
# ============================================================================

def compute_expected_area(a, b, c):
    """
    Compute area of equilateral triangle given distances a,b,c from a point.
    Returns area (float) or -1.0 if no valid triangle exists.
    """
    a2 = a*a
    b2 = b*b
    c2 = c*c
    
    S = a2 + b2 + c2
    
    # Compute D
    term1 = 2*(a2*b2 + a2*c2 + b2*c2)
    term2 = a2*a2 + b2*b2 + c2*c2
    D = 3 * (term1 - term2)
    
    if D < 0:
        return -1.0
    
    sqrt_D = math.sqrt(D)
    t = (S + sqrt_D) / 2.0
    
    # Check lower bound conditions
    lb1 = abs(a2 - b2)
    lb2 = 2*c2 - a2 - b2
    lb3 = 2*b2 - a2 - c2
    lb4 = 2*a2 - b2 - c2
    lower_bound = max(lb1, lb2, lb3, lb4)
    
    if t < lower_bound:
        return -1.0
    
    area = (math.sqrt(3) / 4.0) * t
    return area

# ============================================================================
# MAIN TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_area_calculator(dut):
    """Test the area_calculator module with provided test cases."""
    
    # Detect sequential interface
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    
    if not (has_clk and has_rst and has_start and has_done):
        raise TestFailure("Module missing required signals: clk, rst_n, start, done")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (a, b, c, expected_area)
    test_cases = [
        (1.0, 1.0, 1.732050, 1.732050808),
        (1.0, 1.0, 3.0, -1.0),
        (1.732051, 1.732051, 1.732051, 3.897115183),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_in, b_in, c_in, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: a={a_in}, b={b_in}, c={c_in}")
        
        # Convert inputs to Q16.16
        a_q = float_to_q1616(a_in)
        b_q = float_to_q1616(b_in)
        c_q = float_to_q1616(c_in)
        
        # Assign to DUT
        dut.a.value = a_q
        dut.b.value = b_q
        dut.c.value = c_q
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        cycles = 0
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read output
        if not is_value_defined(dut.area.value):
            raise TestFailure("Output area is undefined (X/Z)")
        
        area_out = int(dut.area.value)
        
        # Convert expected to Q16.16
        if expected < 0:
            expected_q = 0xFFFFFFFF  # Special code for -1
        else:
            expected_q = float_to_q1616(expected)
        
        # Compare
        if area_out != expected_q:
            # Convert to float for error message
            if area_out == 0xFFFFFFFF:
                area_float = -1.0
            else:
                area_float = q1616_to_float(area_out)
            dut._log.error(f"  FAIL: Expected {expected} (Q: {expected_q:#x}), got {area_float} (Q: {area_out:#x})")
            failed += 1
        else:
            dut._log.info(f"  PASS: area = {expected if expected >= 0 else -1.0}")
            passed += 1
        
        # Wait a few cycles before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")