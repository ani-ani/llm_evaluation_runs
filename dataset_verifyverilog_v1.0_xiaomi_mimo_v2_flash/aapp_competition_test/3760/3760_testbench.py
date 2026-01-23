import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000  # GCD can take many cycles for large numbers

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# ALGORITHM IMPLEMENTATION
# ============================================================================

def gcd(a, b):
    """Compute GCD of two numbers."""
    while b:
        a, b = b, a % b
    return a

def compute_rectangle_python(n, m, x, y, a, b):
    """Reference Python implementation."""
    r = gcd(a, b)
    a_red = a // r
    b_red = b // r
    k = min(n // a_red, m // b_red)
    width = a_red * k
    height = b_red * k
    cx = (width + 1) // 2
    cy = (height + 1) // 2
    dx = min(n - width, max(cx, x) - cx)
    dy = min(m - height, max(cy, y) - cy)
    return dx, dy, dx + width, dy + height

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_find_rectangle(dut):
    """Test the find_rectangle module."""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if not is_sequential:
        raise TestFailure("Module must have clk and done signals for sequential operation")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Test cases (scaled for simulation)
    # Original inputs are huge, we'll test with smaller representative values
    # We also include some edge cases
    test_cases = [
        # (n, m, x, y, a, b) -> expected (x1, y1, x2, y2)
        (9, 9, 5, 5, 2, 1, 1, 3, 9, 7),
        (100, 100, 52, 50, 46, 56, 17, 8, 86, 92),
        (10, 10, 5, 5, 1, 1, 0, 0, 10, 10),
        (20, 20, 10, 10, 2, 1, 0, 5, 20, 15),
        (50, 30, 25, 15, 3, 2, 0, 0, 48, 30),
        (100, 100, 50, 50, 1, 2, 25, 0, 75, 100),
        (8, 8, 4, 4, 3, 1, 0, 2, 6, 8),
        (100, 100, 50, 50, 5, 5, 0, 0, 100, 100),
        (100, 100, 0, 0, 1, 1, 0, 0, 100, 100),
        (100, 100, 100, 100, 1, 1, 0, 0, 100, 100),
        # Edge case: point at corner
        (10, 10, 0, 0, 2, 1, 0, 0, 10, 5),
        (10, 10, 10, 10, 2, 1, 0, 5, 10, 10),
        # Large aspect ratio
        (100, 100, 50, 50, 100, 1, 0, 49, 100, 51),
        (100, 100, 50, 50, 1, 100, 49, 0, 51, 100),
        # Small grid
        (5, 5, 2, 2, 2, 1, 0, 1, 5, 5),
        (5, 5, 2, 2, 1, 2, 1, 0, 5, 5),
        # Grid size limiting
        (10, 20, 5, 10, 3, 1, 0, 9, 9, 19),
        (20, 10, 10, 5, 1, 3, 9, 0, 19, 10),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, x, y, a, b, exp_x1, exp_y1, exp_x2, exp_y2) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: n={n}, m={m}, x={x}, y={y}, a={a}, b={b}")
        
        try:
            # Write inputs (clamp to 32-bit)
            dut.n.value = clamp_to_width(n, DATA_WIDTH)
            dut.m.value = clamp_to_width(m, DATA_WIDTH)
            dut.x.value = clamp_to_width(x, DATA_WIDTH)
            dut.y.value = clamp_to_width(y, DATA_WIDTH)
            dut.a.value = clamp_to_width(a, DATA_WIDTH)
            dut.b.value = clamp_to_width(b, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=5000)
            
            # Read results
            if not all([is_value_defined(dut.x1.value), is_value_defined(dut.y1.value),
                       is_value_defined(dut.x2.value), is_value_defined(dut.y2.value)]):
                raise TestFailure("Output contains undefined (X/Z) values")
            
            x1 = int(dut.x1.value)
            y1 = int(dut.y1.value)
            x2 = int(dut.x2.value)
            y2 = int(dut.y2.value)
            
            # Verify with Python reference
            py_x1, py_y1, py_x2, py_y2 = compute_rectangle_python(n, m, x, y, a, b)
            
            # Check if matches expected
            if (x1, y1, x2, y2) == (exp_x1, exp_y1, exp_x2, exp_y2):
                cocotb.log.info(f"  PASS: Got ({x1}, {y1}, {x2}, {y2})")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: Expected ({exp_x1}, {exp_y1}, {exp_x2}, {exp_y2}), got ({x1}, {y1}, {x2}, {y2})")
                cocotb.log.error(f"  Python reference: ({py_x1}, {py_y1}, {py_x2}, {py_y2})")
                failed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")