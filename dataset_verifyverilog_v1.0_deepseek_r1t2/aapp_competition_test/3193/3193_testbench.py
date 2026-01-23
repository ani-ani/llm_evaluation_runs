import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000  # Scaled down: M <= 256, so 1000 cycles is safe

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

# ============================================================================
# EXPRESSION EVALUATION (Python side)
# ============================================================================

def evaluate_expression(expr, x_val):
    """Evaluate expression with given x value."""
    # Replace x with the value
    expr_replaced = expr.replace('x', str(x_val))
    # Evaluate safely using eval
    try:
        return int(eval(expr_replaced))
    except:
        raise TestFailure(f"Failed to evaluate expression: {expr_replaced}")

def compute_coefficients(expr):
    """Compute a and b for expression a*x + b."""
    value0 = evaluate_expression(expr, 0)
    value1 = evaluate_expression(expr, 1)
    a = value1 - value0
    b = value0
    return a, b

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_solve_linear_congruence(dut):
    """Test the linear congruence solver with scaled-down expressions."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (expression, P, M, expected_x)
    # Scaled down: M <= 256, expression length <= 100
    test_cases = [
        ("5+3+x", 9, 10, 1),        # Original example
        ("20+3+x", 0, 5, 2),       # Original example
        ("3*(x+(x+4)*5)", 1, 7, 1), # Original example
        ("2*x+5", 3, 7, 4),         # Simple linear
        ("x+x+x", 3, 5, 1),         # x appears multiple times
        ("10-x", 5, 7, 5),          # Subtraction
        ("2*(3*x+4)+x", 1, 11, 1),  # Nested operations
    ]
    
    passed = 0
    failed = 0
    
    for i, (expr, P, M, expected_x) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: expr='{expr}', P={P}, M={M}, expected={expected_x}")
        
        try:
            # Compute coefficients using Python
            a, b = compute_coefficients(expr)
            cocotb.log.info(f"  Computed: a={a}, b={b}")
            
            # Clamp values to 32-bit signed range
            MAX_32 = (1 << 31) - 1
            MIN_32 = -(1 << 31)
            a_clamped = max(MIN_32, min(MAX_32, a))
            b_clamped = max(MIN_32, min(MAX_32, b))
            
            # Assign inputs
            dut.a.value = from_signed(a_clamped, 32)
            dut.b.value = from_signed(b_clamped, 32)
            dut.P.value = P
            dut.M.value = M
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.x.value):
                raise TestFailure("Result x is undefined (X/Z)")
            
            result = int(dut.x.value)
            
            if result != expected_x:
                raise TestFailure(f"Expected {expected_x}, got {result}")
            
            cocotb.log.info(f"  PASS: x = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
