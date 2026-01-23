import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
N = 8
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_lengths(dut, lengths):
    """Write lengths array to DUT."""
    for i in range(N):
        if i < len(lengths):
            dut.lengths[i].value = clamp_to_width(lengths[i], DATA_WIDTH)
        else:
            dut.lengths[i].value = 0

async def read_area(dut):
    """Read area output from DUT."""
    if is_value_defined(dut.area.value):
        return int(dut.area.value)
    else:
        raise TestFailure("Area output is undefined (X/Z)")

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# COMPUTE EXPECTED AREA (TRIANGLE/QUADRILATERAL ONLY)
# ============================================================================

def compute_triangle_area(a, b, c):
    """Compute area of triangle using Heron's formula."""
    if a + b <= c or a + c <= b or b + c <= a:
        return None
    s = (a + b + c) / 2.0
    area = math.sqrt(s * (s - a) * (s - b) * (s - c))
    return area

def compute_quadrilateral_area(a, b, c, d):
    """Compute area of cyclic quadrilateral using Brahmagupta's formula."""
    P = a + b + c + d
    max_side = max(a, b, c, d)
    if max_side >= P - max_side:
        return None
    s = P / 2.0
    area = math.sqrt((s - a) * (s - b) * (s - c) * (s - d))
    return area

def max_area_from_lengths(lengths):
    """Compute maximum area among triangles and quadrilaterals."""
    max_area = 0.0
    n = len(lengths)
    # Triangles
    for i in range(n):
        for j in range(i + 1, n):
            for k in range(j + 1, n):
                area = compute_triangle_area(lengths[i], lengths[j], lengths[k])
                if area is not None and area > max_area:
                    max_area = area
    # Quadrilaterals
    for i in range(n):
        for j in range(i + 1, n):
            for k in range(j + 1, n):
                for l in range(k + 1, n):
                    area = compute_quadrilateral_area(lengths[i], lengths[j], lengths[k], lengths[l])
                    if area is not None and area > max_area:
                        max_area = area
    return max_area

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_polygon_area(dut):
    """Test the max_polygon_area module."""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (lengths, expected_area)
    # Note: expected_area is computed using triangles/quadrilaterals only
    test_cases = [
        ([1, 1, 1, 1], 1.0),          # Square: 1.0
        ([1, 1, 1], 0.4330127018922193),  # Equilateral triangle: sqrt(3)/4
        ([1, 1, 2, 2, 7], 2.0),       # Quadrilateral: 1,1,2,2 -> area 2.0
    ]
    
    passed = 0
    failed = 0
    
    for test_i, (lengths, expected_area) in enumerate(test_cases):
        # Validate length count (must be <= N)
        if len(lengths) > N:
            cocotb.log.error(f"Test {test_i+1}: length count {len(lengths)} exceeds N={N}")
            failed += 1
            continue
        
        # Compute expected area using our algorithm
        computed_area = max_area_from_lengths(lengths)
        # Round to 3 decimal places for comparison (error tolerance 0.005)
        expected_scaled = round(computed_area * 10000)
        
        cocotb.log.info(f"Test {test_i+1}: lengths={lengths}, expected area={computed_area:.4f}")
        
        # Write inputs
        await write_lengths(dut, lengths)
        dut.valid_length.value = len(lengths)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result_scaled = await read_area(dut)
        result_area = result_scaled / 10000.0
        
        # Compare with expected (allow 0.005 absolute error)
        abs_error = abs(result_area - computed_area)
        if abs_error <= 0.005:
            cocotb.log.info(f"  PASS: result={result_area:.4f}, error={abs_error:.4f}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected={computed_area:.4f}, got={result_area:.4f}, error={abs_error:.4f}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
