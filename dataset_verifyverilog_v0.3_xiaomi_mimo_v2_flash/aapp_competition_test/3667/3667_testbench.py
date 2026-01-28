import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
MAX_WELLS = 4
MAX_PIPES = 8
INDEX_WIDTH = 3
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
    return min(max_val, max(0, value))

# ============================================================================
# HELPER FUNCTIONS FOR SETTING INPUTS
# ============================================================================

async def set_well(dut, index, x, y):
    if index >= MAX_WELLS:
        raise TestFailure(f"Well index {index} exceeds MAX_WELLS")
    getattr(dut, f"well_x_{index}").value = x
    getattr(dut, f"well_y_{index}").value = y

async def set_pipe(dut, index, start_well, end_x, end_y):
    if index >= MAX_PIPES:
        raise TestFailure(f"Pipe index {index} exceeds MAX_PIPES")
    if start_well >= (1 << INDEX_WIDTH):
        raise TestFailure(f"Start well index {start_well} too large")
    getattr(dut, f"pipe_start_{index}").value = start_well
    getattr(dut, f"pipe_end_x_{index}").value = end_x
    getattr(dut, f"pipe_end_y_{index}").value = end_y

async def set_inputs(dut, well_count, pipe_count, wells, pipes):
    dut.well_count.value = well_count
    dut.pipe_count.value = pipe_count
    for i in range(MAX_WELLS):
        if i < well_count:
            x, y = wells[i]
            await set_well(dut, i, x, y)
        else:
            await set_well(dut, i, 0, 0)
    for i in range(MAX_PIPES):
        if i < pipe_count:
            start_well, end_x, end_y = pipes[i]
            await set_pipe(dut, i, start_well, end_x, end_y)
        else:
            await set_pipe(dut, i, 0, 0, 0)

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
async def test_water_robots(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (
            3, 3,
            [(0, 0), (0, 2), (2, 0)],
            [(0, 2, 3), (1, 2, 2), (2, 0, 3)],
            0,
            "Sample 1: triangle"
        ),
        (
            2, 3,
            [(0, 0), (0, 10)],
            [(0, 5, 15), (0, 2, 15), (1, 10, 10)],
            1,
            "Sample 2: star"
        ),
        (
            2, 4,
            [(0, 0), (5, 5)],
            [(0, 10, 0), (0, 0, 10), (1, 10, 10), (1, 5, 0)],
            1,
            "Additional: bipartite graph"
        ),
        (
            2, 3,
            [(0, 0), (0, 10)],
            [(0, -5, 15), (0, -2, 15), (1, 10, 10)],
            1,
            "Negative coordinates"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (well_cnt, pipe_cnt, wells, pipes, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\\nTest {i+1}: {desc}")
        try:
            await set_inputs(dut, well_cnt, pipe_cnt, wells, pipes)
            await start_computation(dut)
            await wait_for_done(dut)
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")