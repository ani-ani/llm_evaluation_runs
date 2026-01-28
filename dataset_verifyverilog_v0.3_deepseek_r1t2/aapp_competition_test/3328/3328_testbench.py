import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 16
K_MAX = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# Helper functions
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return 0
    return min(max_val, value)

async def write_grid(dut, grid_values):
    for i in range(4):
        for j in range(4):
            dut.grid[i][j].value = clamp_to_width(grid_values[i*4 + j], DATA_WIDTH)

async def read_min_sum(dut):
    if is_value_defined(dut.min_sum.value):
        return int(dut.min_sum.value)
    return None

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_domino_min_sum(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([2,7,6,0, 9,5,1,0, 4,3,8,0, 0,0,0,0], 1, 31),
        ([1,2,4,0, 4,0,5,4, 0,3,5,1, 1,0,4,1], 2, 17),
        ([0]*16, 2, 0),
        ([1]*16, 8, 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid_vals, k, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: K={k}, expected={expected}")
        await write_grid(dut, grid_vals)
        dut.K.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            continue
        result = await read_min_sum(dut)
        if result is None:
            cocotb.log.error("  FAIL: min_sum is undefined")
            failed += 1
            continue
        if result != expected:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")