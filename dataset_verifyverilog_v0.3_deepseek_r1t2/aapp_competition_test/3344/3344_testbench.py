import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8        # POS_WIDTH
ARRAY_SIZE = 4        # MAX_N
RESULT_WIDTH = 16     # V_INT_WIDTH + V_FRAC_WIDTH
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_luggage_speed(dut):
    """Test the luggage_speed module with scaled-down examples."""
    # Detect interface
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if not is_sequential:
        raise TestFailure("DUT is not sequential (missing clk/done)")

    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases: (num_luggage, L, positions_list, expected_v)
    # expected_v is integer representation with 8 fractional bits (v * 256)
    test_cases = [
        (2, 8, [0, 8], 2048),    # v = 8.0
        (2, 8, [0, 4], 1024),    # v = 4.0
        (3, 8, [0, 2, 7], 512),  # v = 2.0
    ]

    passed = 0
    failed = 0

    for case_idx, (num, L, positions, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest case {case_idx+1}: num={num}, L={L}, positions={positions}, expected={expected}")

        # Set num_luggage and L
        if has_signal(dut, 'num_luggage'):
            dut.num_luggage.value = num
        else:
            raise TestFailure("Missing input: num_luggage")

        if has_signal(dut, 'L'):
            dut.L.value = L
        else:
            raise TestFailure("Missing input: L")

        # Write positions (only the first 'num' elements)
        # Assume DUT has a 2D array 'pos' of size ARRAY_SIZE
        for i in range(ARRAY_SIZE):
            if i < num:
                val = positions[i]
                # Clamp to DATA_WIDTH (though positions are within 0..L <=8, so safe)
                dut.pos[i].value = clamp_to_width(val, DATA_WIDTH)
            else:
                # Set unused positions to a large value (outside belt) to avoid affecting result
                # The DUT should ignore them because num_luggage is set
                dut.pos[i].value = 0xFF  # 255, far outside 0..8

        # Start computation
        await start_computation(dut)

        # Wait for done
        await wait_for_done(dut)

        # Read result (v)
        if not is_value_defined(dut.v.value):
            raise TestFailure(f"Test {case_idx+1}: v output is undefined (X/Z)")

        result = int(dut.v.value)

        # Compare with expected
        if result != expected:
            raise TestFailure(f"Test {case_idx+1}: expected {expected}, got {result}")

        cocotb.log.info(f"  PASS: v = {result} (expected {expected})")
        passed += 1

        # Wait one cycle before next test
        await RisingEdge(dut.clk)

    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
