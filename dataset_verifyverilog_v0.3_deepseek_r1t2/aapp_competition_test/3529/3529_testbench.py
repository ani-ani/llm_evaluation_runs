import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

def pack_edge(color, src, dst):
    return (color << 6) | (src << 3) | dst

async def write_edges(dut, edges, M=32):
    for i in range(M):
        if i < len(edges):
            val = edges[i]
        else:
            val = pack_edge(0, 0, 0)
        dut.edge[i].value = val

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_spanning_tree_checker(dut):
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if not is_sequential:
        raise TestFailure("Module must be sequential with clk and done signals")
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    test_cases = [
        ([(1,0,1), (1,1,2), (0,2,0)], 2, 1, "Example 1: n=3, k=2"),
        ([(0,0,1)], 1, 0, "Example 2: n=2, k=1"),
    ]
    passed = 0
    failed = 0
    for edges, k, expected, description in test_cases:
        cocotb.log.info(f"Running test: {description}")
        await write_edges(dut, edges)
        dut.k.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined (X/Z)")
        result = int(dut.result.value)
        if result == expected:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")