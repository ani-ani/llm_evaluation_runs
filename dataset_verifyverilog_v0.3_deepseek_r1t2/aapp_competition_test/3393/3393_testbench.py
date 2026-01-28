import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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

DATA_WIDTH = 8
RESULT_WIDTH = 16
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000  # plenty for 256 masks + overhead

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_course_selection(dut):
    """Main test for the course selection module."""

    # Detect interface
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')

    if not (has_clk and has_rst and has_start and has_done):
        raise TestFailure("DUT missing required signals (clk, rst_n, start, done)")

    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to wait for done
    async def wait_for_done(max_cycles=MAX_CYCLES):
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return
        raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

    # Test cases derived from the problem
    test_cases = [
        {
            "name": "Sample 1",
            "k": 2,
            "courses": [
                {"name": "linearalgebra", "diff": 10, "type": "standalone"},
                {"name": "calculus1", "diff": 10, "type": "I"},
                {"name": "calculus2", "diff": 20, "type": "II", "pair": "calculus1"},
                {"name": "honorsanalysis1", "diff": 50, "type": "I"},
                {"name": "honorsanalysis2", "diff": 100, "type": "II", "pair": "honorsanalysis1"},
            ],
            "expected": 20,
        },
        {
            "name": "Sample 2",
            "k": 5,
            "courses": [
                {"name": "introtocs", "diff": 40, "type": "standalone"},
                {"name": "algorithms1", "diff": 50, "type": "I"},
                {"name": "algorithms2", "diff": 200, "type": "II", "pair": "algorithms1"},
                {"name": "datastructures", "diff": 120, "type": "standalone"},
                {"name": "theoryofcomputation", "diff": 200, "type": "standalone"},
                {"name": "machinelearning1", "diff": 100, "type": "I"},
                {"name": "machinelearning2", "diff": 50, "type": "II", "pair": "machinelearning1"},
            ],
            "expected": 360,
        },
    ]

    for test in test_cases:
        dut._log.info(f"Running test: {test['name']} (k={test['k']})")

        # Prepare arrays for the 8 courses
        diff = [255] * ARRAY_SIZE          # default high difficulty
        is_level2 = [0] * ARRAY_SIZE
        prereq_idx = [0] * ARRAY_SIZE
        name_to_index = {}
        index = 0

        # First pass: assign indices to courses
        for course in test['courses']:
            if index >= ARRAY_SIZE:
                raise TestFailure(f"Too many courses in test {test['name']}")
            name_to_index[course['name']] = index
            diff[index] = course['diff']
            index += 1

        # Second pass: set Level II prerequisites
        for course in test['courses']:
            if course['type'] == "II":
                i = name_to_index[course['name']]
                pair_name = course['pair']
                if pair_name not in name_to_index:
                    raise TestFailure(f"Pair {pair_name} not found for {course['name']}")
                j = name_to_index[pair_name]
                is_level2[i] = 1
                prereq_idx[i] = j

        # Assign to DUT
        for i in range(ARRAY_SIZE):
            dut.diff[i].value = clamp_to_width(diff[i], DATA_WIDTH)
            dut.is_level2[i].value = is_level2[i]
            dut.prereq_idx[i].value = prereq_idx[i]
        dut.k.value = test['k']

        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        await wait_for_done()

        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined (X/Z)")
        result = int(dut.result.value)
        expected = test['expected']

        if result != expected:
            raise TestFailure(f"Result mismatch: expected {expected}, got {result}")

        dut._log.info(f"  PASS: result = {result}")

        # Small delay between tests
        await Timer(100, units='ns')

    dut._log.info("All tests passed!")
