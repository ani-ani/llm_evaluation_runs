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

INPUT_WIDTH = 17
OUTPUT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

async def wait_for_combinational(dut, timeout_ns=1000):
    elapsed = 0
    check_interval = 10
    while elapsed < timeout_ns:
        await Timer(check_interval, units='ns')
        elapsed += check_interval
        if is_value_defined(dut.result.value):
            return int(dut.result.value)
    raise TestFailure(f"Output not valid after {timeout_ns}ns")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_cost_ticket(dut):
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (2, 0),
        (10, 4),
        (43670, 21834),
        (4217, 2108),
        (17879, 8939),
        (31809, 15904),
        (40873, 20436),
        (77859, 38929),
        (53022, 26510),
        (79227, 39613),
        (100000, 49999),
        (82801, 41400),
        (5188, 2593),
        (86539, 43269),
        (12802, 6400),
        (20289, 10144),
        (32866, 16432),
        (33377, 16688),
        (31775, 15887),
        (60397, 30198),
        (100000, 49999),
        (99999, 49999),
        (99998, 49998),
        (99997, 49998),
        (99996, 49997),
        (1, 0),
        (2, 0),
        (3, 1),
        (4, 1),
        (1, 0),
        (3, 1)
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, expected={expected}")
        try:
            n_clamped = clamp_to_width(n, INPUT_WIDTH)
            dut.n.value = n_clamped
            if is_sequential:
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                await wait_for_combinational(dut)
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