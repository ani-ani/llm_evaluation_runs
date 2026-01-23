import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
REQ_WIDTH = 10
ARRAY_SIZE = 16
RESULT_WIDTH = 24  # Q12.12 format
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
FRAC_BITS = 12

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_arrays(dut, a_values, b_values, element_width):
    """Write a and b arrays to DUT."""
    # Write a array
    for i, val in enumerate(a_values):
        if i < ARRAY_SIZE:
            dut.a[i].value = clamp_to_width(val, element_width)
    
    # Write b array
    for i, val in enumerate(b_values):
        if i < ARRAY_SIZE:
            dut.b[i].value = clamp_to_width(val, element_width)

async def read_result(dut):
    """Read and convert result from Q12.12 to float."""
    if not is_value_defined(dut.result.value):
        return None
    raw = int(dut.result.value)
    return fixed_to_float(raw)

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_days_solver(dut):
    """Test min_days_solver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, p, q, a_list, b_list, expected_days)
    # Values are scaled to fit HDL constraints (n<=16, p,q<=1023, a_i,b_i<=255)
    test_cases = [
        # Original examples (scaled)
        (3, 20, 20, [6, 1, 2], [2, 3, 6], 5.0),
        (4, 1, 1, [2, 3, 2, 3], [3, 2, 3, 2], 0.4),
        
        # Additional test cases
        (3, 12, 12, [5, 2, 1], [1, 2, 5], 4.0),
        (3, 12, 12, [5, 4, 1], [1, 4, 5], 3.0),
        (3, 1, 1, [1, 1, 1], [1, 1, 1], 1.0),
        (1, 4, 6, [2], [3], 2.0),
        (1, 3, 4, [2], [3], 1.5),
        
        # Edge cases with single project
        (2, 1, 1000, [2, 5], [4, 2], 500.0),  # Scaled down from 1000000
        (2, 1000, 1, [2, 5], [4, 2], 200.0),  # Scaled down
        (2, 1000, 1000, [2, 5], [4, 2], 312.5),  # Scaled down
        
        # Small values
        (2, 4, 2, [2, 5], [4, 2], 0.875),
        (2, 4, 4, [2, 5], [4, 2], 1.25),
        (2, 3, 4, [2, 5], [4, 2], 1.125),
        (2, 2, 3, [2, 5], [4, 2], 0.8125),
        (2, 1, 3, [2, 5], [4, 2], 0.75),
        (2, 5, 2, [2, 5], [4, 2], 1.0),
        
        # Multiple identical projects
        (6, 2, 2, [2, 5, 5, 2, 2, 5], [4, 2, 2, 4, 4, 2], 0.625),
        
        # Mixed values
        (2, 10, 3, [2, 5], [4, 2], 2.0),
        (2, 10, 4, [2, 5], [4, 2], 2.0),
        (2, 10, 5, [2, 5], [4, 2], 2.1875),
        (2, 5, 8, [2, 5], [4, 2], 2.125),
        (2, 4, 8, [2, 5], [4, 2], 2.0),
        (2, 3, 8, [2, 5], [4, 2], 2.0),
        (2, 4, 1, [2, 5], [4, 2], 0.8),
        (2, 4, 2, [2, 5], [4, 2], 0.875),
        (2, 4, 3, [2, 5], [4, 2], 1.0625),
        (2, 5, 3, [2, 5], [4, 2], 1.1875),
        (2, 5, 4, [2, 5], [4, 2], 1.375),
        
        # Additional scaled cases
        (2, 5, 4, [2, 4], [2, 3], 1.333333333333333),
        (6, 1000, 999, [999, 995, 996, 997, 998, 1], [1, 994, 996, 995, 997, 998], 1.000002),
        (7, 1234, 1234, [10, 3, 11, 8, 5, 7, 1], [2, 4, 3, 1, 2, 1, 8], 217.8670588235294),
        (10, 1234, 1234, [5, 11, 1, 11, 7, 10, 8, 11, 3, 11], [2, 4, 8, 1, 1, 2, 1, 3, 4, 8], 154.32375),
        (10, 630, 764, [679, 34, 778, 982, 177, 739, 992, 488, 7, 318], [16, 691, 366, 30, 9, 279, 89, 135, 237, 318], 1.472265278375486),
        (10, 468, 93, [589, 279, 470, 467, 295, 104, 925, 922, 998, 425], [627, 672, 377, 416, 213, 604, 284, 423, 583, 304], 0.469139114479426),
        (10, 18, 25, [4, 16, 16, 1, 8, 2, 24, 4, 3, 19], [8, 27, 13, 26, 13, 14, 8, 29, 19, 20], 1.041450777202072),
        (10, 17, 38, [6, 16, 6, 16, 27, 23, 4, 30, 5, 40], [35, 37, 12, 29, 15, 28, 27, 12, 4, 17], 1.036423841059603),
        (10, 36, 35, [32, 17, 20, 11, 24, 25, 37, 14, 32, 17], [37, 30, 24, 21, 9, 6, 23, 8, 20, 39], 1.072669826224329),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, p_val, q_val, a_list, b_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: n={n}, p={p_val}, q={q_val}")
        
        try:
            # Clamp values to fit HDL constraints
            n_clamped = clamp_to_width(n, 4)
            p_clamped = clamp_to_width(p_val, REQ_WIDTH)
            q_clamped = clamp_to_width(q_val, REQ_WIDTH)
            
            # Write inputs
            dut.n.value = n_clamped
            dut.p.value = p_clamped
            dut.q.value = q_clamped
            
            await write_arrays(dut, a_list, b_list, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
            if result is None:
                raise TestFailure(f"Result is undefined (X/Z)")
            
            # Check with tolerance
            tolerance = 1e-6
            abs_error = abs(result - expected)
            rel_error = abs_error / max(1.0, expected)
            
            if rel_error > tolerance and abs_error > tolerance:
                raise TestFailure(
                    f"Expected {expected:.10f}, got {result:.10f} "
                    f"(abs_error={abs_error:.10f}, rel_error={rel_error:.10e})"
                )
            
            cocotb.log.info(f"  PASS: result = {result:.10f} (expected {expected:.10f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases for min_days_solver."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Edge case 1: Single project where one resource dominates
    cocotb.log.info("\nEdge Case 1: Single project, p dominates")
    dut.n.value = 1
    dut.p.value = 100
    dut.q.value = 1
    dut.a[0].value = 50
    dut.b[0].value = 1
    
    await start_computation(dut)
    await wait_for_done(dut)
    result = await read_result(dut)
    
    # Expected: max(100/50, 1/1) = max(2.0, 1.0) = 2.0
    if abs(result - 2.0) > 1e-6:
        raise TestFailure(f"Expected 2.0, got {result}")
    cocotb.log.info(f"  PASS: {result}")
    
    # Edge case 2: All projects identical
    cocotb.log.info("\nEdge Case 2: All identical projects")
    dut.n.value = 3
    dut.p.value = 10
    dut.q.value = 10
    for i in range(3):
        dut.a[i].value = 5
        dut.b[i].value = 5
    
    await start_computation(dut)
    await wait_for_done(dut)
    result = await read_result(dut)
    
    # Expected: max(10/5, 10/5) = 2.0
    if abs(result - 2.0) > 1e-6:
        raise TestFailure(f"Expected 2.0, got {result}")
    cocotb.log.info(f"  PASS: {result}")
    
    # Edge case 3: Very small values
    cocotb.log.info("\nEdge Case 3: Minimum values")
    dut.n.value = 1
    dut.p.value = 1
    dut.q.value = 1
    dut.a[0].value = 1
    dut.b[0].value = 1
    
    await start_computation(dut)
    await wait_for_done(dut)
    result = await read_result(dut)
    
    # Expected: max(1/1, 1/1) = 1.0
    if abs(result - 1.0) > 1e-6:
        raise TestFailure(f"Expected 1.0, got {result}")
    cocotb.log.info(f"  PASS: {result}")
    
    # Edge case 4: Use 16 projects (max)
    cocotb.log.info("\nEdge Case 4: Maximum projects (16)")
    dut.n.value = 15  # 0-15 = 16 elements
    dut.p.value = 500
    dut.q.value = 500
    for i in range(16):
        dut.a[i].value = 10 + i
        dut.b[i].value = 20 - i
    
    await start_computation(dut)
    await wait_for_done(dut)
    result = await read_result(dut)
    
    # Just check it completes and gives reasonable result
    if result is None or result <= 0:
        raise TestFailure(f"Invalid result: {result}")
    cocotb.log.info(f"  PASS: {result}")
    
    cocotb.log.info("\nAll edge cases passed!")
