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
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 8          # for positions
ARRAY_SIZE = 8          # maximum number of e_pos/d_pos elements
N_MAX = 8               # maximum number of players
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000        # timeout for done
NO_WINNER = 255         # value for -1

# ============================================================================
# ARRAY WRITE HELPERS
# ============================================================================

async def write_array(dut, prefix, values, size=ARRAY_SIZE):
    """Write values to individual ports prefix_0, prefix_1, ..."""
    for i in range(size):
        port_name = f"{prefix}_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Signal {port_name} not found")

# ============================================================================
# RESET AND DONE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Active-low reset for 2 cycles."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

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
async def test_exploding_kittens(dut):
    """Test the exploding_kittens module with sample cases."""

    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())

    # Reset
    await reset_dut(dut)

    # Test cases
    test_cases = [
        {
            "name": "Sample 1",
            "N": 2, "E": 4, "D": 3,
            "e_pos": [3, 4, 5, 7],
            "d_pos": [1, 2, 10],
            "expected": 0  # winner player 0
        },
        {
            "name": "Sample 2",
            "N": 3, "E": 5, "D": 2,
            "e_pos": [1, 4, 7, 9, 11],
            "d_pos": [2, 3],
            "expected": 2  # winner player 2
        },
        {
            "name": "Sample 3",
            "N": 3, "E": 3, "D": 2,
            "e_pos": [1, 4, 7],
            "d_pos": [2, 3],
            "expected": NO_WINNER  # no winner
        }
    ]

    for test in test_cases:
        dut._log.info(f"\n=== Running {test['name']} ===")

        # Set inputs
        dut.N.value = test['N']
        dut.E.value = test['E']
        dut.D.value = test['D']

        await write_array(dut, "e_pos", test['e_pos'])
        await write_array(dut, "d_pos", test['d_pos'])

        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        await wait_for_done(dut)

        # Read winner
        if not is_value_defined(dut.winner.value):
            raise TestFailure(f"Winner is undefined (X/Z) in {test['name']}")

        winner = int(dut.winner.value)
        expected = test['expected']

        if winner != expected:
            raise TestFailure(
                f"{test['name']}: expected {expected} (0-7 or 255), got {winner}"
            )

        dut._log.info(f"{test['name']}: PASS (winner = {winner})")

        # Reset for next test
        await reset_dut(dut)

    dut._log.info("\nAll tests passed!")
