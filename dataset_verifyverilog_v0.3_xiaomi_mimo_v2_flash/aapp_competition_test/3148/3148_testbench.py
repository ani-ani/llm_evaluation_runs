import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100
NUM_SWIMMERS = 8  # Maximum number of swimmers
OFFSET = 100      # Offset for lifeguard positions

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    if value < 0:
        # For signed, we assume caller handles conversion
        return value
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# ARRAY WRITE HELPERS
# ============================================================================

async def write_swimmers(dut, swimmers):
    """Write swimmers' coordinates to DUT."""
    # Set n
    dut.n.value = len(swimmers)
    # Write each swimmer's x,y
    for i, (x, y) in enumerate(swimmers):
        if i >= NUM_SWIMMERS:
            break
        # Clamp to 8-bit signed range
        x_clamped = clamp_to_width(from_signed(x, DATA_WIDTH), DATA_WIDTH)
        y_clamped = clamp_to_width(from_signed(y, DATA_WIDTH), DATA_WIDTH)
        getattr(dut, f'x{i}').value = x_clamped
        getattr(dut, f'y{i}').value = y_clamped
    # Set remaining swimmers to zero
    for i in range(len(swimmers), NUM_SWIMMERS):
        getattr(dut, f'x{i}').value = 0
        getattr(dut, f'y{i}').value = 0

async def read_outputs(dut):
    """Read lifeguard positions from DUT."""
    # Wait for outputs to settle (combinational delay)
    await Timer(50, units='ns')
    A_x = safe_int(dut.A_x.value)
    A_y = safe_int(dut.A_y.value)
    B_x = safe_int(dut.B_x.value)
    B_y = safe_int(dut.B_y.value)
    return (A_x, A_y), (B_x, B_y)

# ============================================================================
# SEQUENTIAL HELPERS
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
# COMPUTE EXPECTED MEDIAN (Python)
# ============================================================================

def compute_expected_median(swimmers):
    """Compute median x-coordinate from list of (x,y) tuples."""
    xs = [x for x, y in swimmers]
    xs.sort()
    n = len(xs)
    if n % 2 == 1:
        median = xs[n // 2]
    else:
        # Average of two middle values (integer division)
        median = (xs[n // 2 - 1] + xs[n // 2]) // 2
    return median

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_lifeguard_positions(dut):
    """Test the lifeguard positions module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: list of swimmers (x, y)
    test_cases = [
        # Case 1: 4 swimmers with distinct x
        [(2, 4), (6, -1), (3, 5), (-1, -1)],
        # Case 2: 5 swimmers (odd count)
        [(0, 0), (0, 1), (1, 0), (0, -1), (-1, 0)],
        # Case 3: 8 swimmers (max)
        [(-5, -5), (-3, -3), (-1, -1), (1, 1), (3, 3), (5, 5), (7, 7), (9, 9)],
        # Case 4: Even with duplicate x but distinct after sorting (e.g., 2,2,4,6)
        [(2, 0), (2, 1), (4, 0), (6, 0)],
        # Case 5: All x same (should still work via median)
        [(0, 0), (0, 1), (0, 2), (0, 3)],
    ]
    
    passed = 0
    failed = 0
    
    for idx, swimmers in enumerate(test_cases):
        description = f"Case {idx+1}: {len(swimmers)} swimmers"
        cocotb.log.info(f"\n{description}")
        
        try:
            # Compute expected median
            expected_median = compute_expected_median(swimmers)
            expected_A_x = expected_median - OFFSET
            expected_B_x = expected_median + OFFSET
            expected_A_y = 0
            expected_B_y = 0
            
            # Write inputs
            await write_swimmers(dut, swimmers)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            (A_x, A_y), (B_x, B_y) = await read_outputs(dut)
            
            # Verify
            if A_x != expected_A_x:
                raise TestFailure(f"A_x mismatch: expected {expected_A_x}, got {A_x}")
            if A_y != expected_A_y:
                raise TestFailure(f"A_y mismatch: expected {expected_A_y}, got {A_y}")
            if B_x != expected_B_x:
                raise TestFailure(f"B_x mismatch: expected {expected_B_x}, got {B_x}")
            if B_y != expected_B_y:
                raise TestFailure(f"B_y mismatch: expected {expected_B_y}, got {B_y}")
            
            cocotb.log.info(f"  PASS: A=({A_x},{A_y}), B=({B_x},{B_y})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
