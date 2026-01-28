import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    if value < 0:
        # For signed, we handle separately, but for unsigned assignment use this
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 32
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# ============================================================================
# TEST CASES
# ============================================================================

# Each test case: (description, n, lines, expected_output)
# lines: list of tuples (x0, y0, x1, y1)
# expected_output: -1 for infinite, otherwise integer
TEST_CASES = [
    (
        "Sample 1: 3 lines, 3 intersections",
        3,
        [(1, 3, 9, 5), (2, 2, 6, 8), (4, 8, 9, 3)],
        3
    ),
    (
        "Sample 2: 3 lines, 1 intersection",
        3,
        [(5, 2, 7, 10), (7, 4, 4, 10), (2, 4, 10, 8)],
        1
    ),
    (
        "Sample 3: 3 lines, 1 intersection",
        3,
        [(2, 1, 6, 5), (2, 5, 5, 4), (5, 1, 7, 7)],
        1
    ),
    (
        "Sample 4: 2 lines touching at endpoint",
        2,
        [(-1, -2, -1, -1), (-1, 2, -1, -1)],
        1
    ),
    (
        "Sample 5: 2 lines collinear overlapping -> infinite",
        2,
        [(0, 0, 2, 2), (1, 1, -5, -5)],
        -1
    ),
]

# Dummy line for when n=2 (far away, not intersecting)
DUMMY_LINE = (1000, 1000, 1001, 1001)  # slope 1, far from test cases

# ============================================================================
# HELPER TO WRITE LINE DATA
# ============================================================================

async def write_line(dut, line_index, x0, y0, x1, y1):
    """Write a single line's coordinates to the DUT."""
    signals = [
        (f'x0_{line_index}', x0),
        (f'y0_{line_index}', y0),
        (f'x1_{line_index}', x1),
        (f'y1_{line_index}', y1)
    ]
    for name, value in signals:
        sig = getattr(dut, name)
        # Value is within 32-bit signed range, no clamping needed
        sig.value = value

async def set_line_valid(dut, n):
    """Set line_valid bits based on n (1-3)."""
    # Build 3-bit mask
    mask = 0
    if n >= 1:
        mask |= 1
    if n >= 2:
        mask |= 2
    if n >= 3:
        mask |= 4
    dut.line_valid.value = mask

# ============================================================================
# RESET AND START HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_line_intersection_counter(dut):
    """Test the LineIntersectionCounter module with all sample cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Run each test case
    for i, (description, n, lines, expected) in enumerate(TEST_CASES):
        dut._log.info(f"\nTest {i+1}: {description}")
        
        # Set line_valid mask
        await set_line_valid(dut, n)
        
        # Write line data
        for idx, (x0, y0, x1, y1) in enumerate(lines):
            await write_line(dut, idx, x0, y0, x1, y1)
        
        # For n=2, we have only two lines, but the module expects three.
        # The third line is ignored due to line_valid, but we still assign it.
        if n == 2:
            await write_line(dut, 2, *DUMMY_LINE)
        elif n == 1:
            # Also assign dummy for line1 and line2
            await write_line(dut, 1, *DUMMY_LINE)
            await write_line(dut, 2, *DUMMY_LINE)
        
        # Wait a cycle for inputs to stabilize
        await RisingEdge(dut.clk)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.count.value):
            raise TestFailure(f"Test {i+1}: count is undefined (X/Z)")
        
        result_raw = int(dut.count.value)
        result = to_signed(result_raw, RESULT_WIDTH)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: count = {result}")
        
        # Wait for next test (ensure done is low)
        await FallingEdge(dut.done)
        await RisingEdge(dut.clk)
    
    dut._log.info("\n" + "="*50)
    dut._log.info("All tests passed!")

# ============================================================================
# ADDITIONAL TEST FOR INFINITE CASE HANDLING
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_infinite_detection(dut):
    """Additional test to verify infinite case detection."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Collinear overlapping lines (same as sample 5)
    lines = [(0, 0, 2, 2), (1, 1, -5, -5)]
    
    await set_line_valid(dut, 2)
    for idx, (x0, y0, x1, y1) in enumerate(lines):
        await write_line(dut, idx, x0, y0, x1, y1)
    # Dummy third line
    await write_line(dut, 2, *DUMMY_LINE)
    
    await RisingEdge(dut.clk)
    await start_computation(dut)
    await wait_for_done(dut)
    
    if not is_value_defined(dut.count.value):
        raise TestFailure("Infinite test: count undefined")
    
    result_raw = int(dut.count.value)
    result = to_signed(result_raw, RESULT_WIDTH)
    
    if result != -1:
        raise TestFailure(f"Infinite test: expected -1, got {result}")
    
    dut._log.info("Infinite detection test passed.")
