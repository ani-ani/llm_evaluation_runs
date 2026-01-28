import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH_N = 32
DATA_WIDTH_D = 8
DATA_WIDTH_E = 8
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_currency_exchange(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (100, 60, 70, 40),
        (410, 55, 70, 5),
        (600, 60, 70, 0),
        (50, 60, 70, 50),
        (420, 70, 65, 0),
        (1750, 45, 50, 0),
        (100000000, 31, 33, 0),
        (99, 100, 100, 99),
        (99999998, 60, 75, 8),
        (90, 80, 89, 10),
        (999, 66, 74, 9),
        (420, 65, 70, 5),
        (1000, 63, 70, 20),
        (1000, 60, 80, 0),
        (8642, 70, 90, 2),
        (10000, 68, 78, 2),
        (11750, 49, 50, 0),
        (54321, 63, 70, 1),
        (99998, 68, 78, 0),
        (99999, 70, 75, 4),
        (100005, 60, 70, 5),
        (9876543, 66, 88, 17),
        (99750, 50, 51, 0),
        (12149750, 45, 50, 0),
        (23456789, 66, 100, 1),
        (99999999, 90, 100, 9),
        (100000000, 98, 99, 0),
        (1, 30, 30, 1),
        (100000000, 30, 30, 10),
        (150, 31, 30, 0),
        (30, 31, 30, 30),
        (511, 100, 31, 1),
        (130, 100, 30, 30),
        (99, 97, 33, 2),
        (59, 87, 30, 59),
        (495, 30, 31, 0),
        (16091, 51, 96, 2),
        (898, 99, 30, 1),
        (39610651, 75, 98, 1),
        (311, 31, 30, 1),
        (100000, 35, 35, 0),
        (13795, 97, 31, 2),
        (90852542, 95, 34, 0),
        (150, 100, 30, 51),
        (169, 59, 37, 10),
        (99999989, 31, 30, 0),
        (400, 30, 100, 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, d_val, e_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, d={d_val}, e={e_val}, expected={expected}")
        dut.n.value = clamp_to_width(n_val, DATA_WIDTH_N)
        dut.d.value = clamp_to_width(d_val, DATA_WIDTH_D)
        dut.e.value = clamp_to_width(e_val, DATA_WIDTH_E)
        await start_computation(dut)
        await wait_for_done(dut)
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        result = int(dut.result.value)
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