import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
R = 3
S = 3
DATA_WIDTH = 12          # Enough for values up to ±2047
AREA_WIDTH = 6           # Max area 9 fits in 4 bits, 6 is safe
CLK_PERIOD_NS = 10

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

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_matrix(dut, matrix):
    """Write 2D matrix to flattened array, clamping values."""
    flat = [val for row in matrix for val in row]
    for i, val in enumerate(flat):
        dut.matrix_flat[i].value = clamp_to_width(val, DATA_WIDTH)

async def read_max_area(dut):
    """Read the max_area output safely."""
    if is_value_defined(dut.max_area.value):
        return int(dut.max_area.value)
    return 0

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

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for _ in range(max_cycles):
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_extremely_cool_matrix(dut):
    """Test the extremely_cool matrix module."""

    # Detect interface
    is_sequential = has_signal(dut, 'clk')

    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)

    # Define test cases: (matrix, expected_area, description)
    test_cases = [
        (
            [
                [1, 4, 10],
                [5, 2, 6],
                [11, 1, 3]
            ],
            9,
            "Sample 1: entire matrix is extremely cool"
        ),
        (
            [
                [1, 3, 1],
                [2, 1, 2],
                [1, 1, 1]
            ],
            4,
            "Sample 2: max area 4"
        ),
        (
            [
                [1, 2],
                [3, 4]
            ],
            4,
            "2x2 matrix, should be extremely cool"
        ),
        (
            [
                [0, 0],
                [0, 0]
            ],
            4,
            "All zeros, extremely cool"
        ),
        (
            [
                [10, 20],
                [30, 40]
            ],
            4,
            "Linear matrix, extremely cool"
        ),
    ]

    passed = 0
    failed = 0

    for i, (matrix, expected, description) in enumerate(test_cases):
        # Skip if matrix size doesn't match parameters
        if len(matrix) != R or len(matrix[0]) != S:
            cocotb.log.info(f"Skipping test {i+1}: size mismatch")
            continue

        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"Matrix:")
        for row in matrix:
            cocotb.log.info(f"  {row}")

        try:
            # Write matrix to DUT
            await write_matrix(dut, matrix)

            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')

            # Read result
            result = await read_max_area(dut)

            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")

            cocotb.log.info(f"  PASS: max_area = {result}")
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1

    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
