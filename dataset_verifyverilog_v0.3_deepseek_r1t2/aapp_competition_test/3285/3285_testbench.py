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
    if value < 0:
        return from_signed(max(-((1 << (bits - 1))), min((1 << (bits - 1)) - 1, value)), bits)
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_sds_finder(dut):
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        dut._log.error('Sequential module required')
        raise TestFailure('No clock signal')

    test_cases = [
        (1, 5, 4),
        (1, 12, 4),
        (5, 1, 2),
    ]

    passed = 0
    failed = 0

    for i, (r, m, expected_n) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: r={r}, m={m}')
        dut.r.value = r
        dut.m.value = m
        await start_computation(dut)
        await wait_for_done(dut)
        n_val = safe_int(dut.n.value)
        found_val = safe_int(dut.found.value)
        if found_val != 1:
            dut._log.error(f'  FAIL: found expected 1, got {found_val}')
            failed += 1
        elif n_val != expected_n:
            dut._log.error(f'  FAIL: n expected {expected_n}, got {n_val}')
            failed += 1
        else:
            dut._log.info(f'  PASS: n={n_val}, found={found_val}')
            passed += 1

    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')
