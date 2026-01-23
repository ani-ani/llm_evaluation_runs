import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8
SPOT_WIDTH = 8
IDX_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# HELPER FUNCTIONS FOR THIS TESTBENCH
# ============================================================================
def pack_spots(spots, spot_width=SPOT_WIDTH):
    """Pack list of spot values into a single integer."""
    packed = 0
    for i, val in enumerate(spots):
        packed |= (val & ((1 << spot_width) - 1)) << (i * spot_width)
    return packed

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_frog_jumps(dut):
    """Test the frog_jumps module with scaled-down test cases."""

    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())

    # Reset DUT
    await reset_dut(dut)

    # Test cases: (spots_list, expected_max_index)
    # Original problem:
    #  7
    #  2 1 0 1 2 3 3   -> farthest reachable index = 5
    #  11
    #  7 6 1 4 1 2 1 4 1 4 5 -> farthest reachable index = 10
    test_cases = [
        ([2, 1, 0, 1, 2, 3, 3], 5),
        ([7, 6, 1, 4, 1, 2, 1, 4, 1, 4, 5], 10),
    ]

    for idx, (spots_list, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {idx+1}")

        # Pad or truncate spots_list to exactly N elements
        if len(spots_list) < N:
            spots_list = spots_list + [0] * (N - len(spots_list))
        else:
            spots_list = spots_list[:N]

        # Pack spots and assign to DUT
        packed = pack_spots(spots_list)
        dut.spots_flat.value = packed

        # Pulse start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break

        if not done:
            raise TestFailure(f"Test {idx+1}: done not asserted within {MAX_CYCLES} cycles")

        # Read and verify result
        if not is_value_defined(dut.max_index.value):
            raise TestFailure(f"Test {idx+1}: max_index is undefined (X/Z)")

        result = int(dut.max_index.value)
        if result != expected:
            raise TestFailure(f"Test {idx+1}: expected {expected}, got {result}")

        dut._log.info(f"  PASS: max_index = {result}")

    dut._log.info("All tests passed!")
