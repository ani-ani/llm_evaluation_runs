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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_evenland(dut):
    """Test the evenland module with sample inputs."""

    # Constants matching the HDL design
    N_WIDTH = 4      # N is 4 bits (1-8)
    M_WIDTH = 5      # M is 5 bits (1-16)
    VTX_WIDTH = 3    # Vertex index is 3 bits (1-8)
    RESULT_WIDTH = 32

    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Reset
    await reset_dut(dut)

    # Define test cases
    test_cases = [
        # (N, M, edges, expected_result)
        (4, 5, [(1,2), (1,3), (1,4), (2,3), (2,4)], 4),   # Sample 1
        (2, 1, [(1,2)], 1),                                 # Sample 2
    ]

    for case_idx, (N_val, M_val, edges, expected) in enumerate(test_cases):
        dut._log.info(f"\n{'='*50}")
        dut._log.info(f"Test case {case_idx+1}: N={N_val}, M={M_val}")

        # Provide N and M before start
        dut.N.value = clamp_to_width(N_val, N_WIDTH)
        dut.M.value = clamp_to_width(M_val, M_WIDTH)

        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Feed edges sequentially
        for i, (a, b) in enumerate(edges):
            dut._log.info(f"  Edge {i+1}: {a}-{b}")
            dut.edge_a.value = clamp_to_width(a, VTX_WIDTH)
            dut.edge_b.value = clamp_to_width(b, VTX_WIDTH)
            dut.edge_valid.value = 1
            await RisingEdge(dut.clk)
            dut.edge_valid.value = 0
            # Wait one cycle (the DUT processes the edge)
            await RisingEdge(dut.clk)

        # Wait for done
        await wait_for_done(dut)

        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")

        result = int(dut.result.value)
        dut._log.info(f"  Result: {result}, Expected: {expected}")

        if result != expected:
            raise TestFailure(f"Result mismatch: expected {expected}, got {result}")

        # Small delay before next test case
        await Timer(100, units='ns')

    dut._log.info("\nAll tests passed!")