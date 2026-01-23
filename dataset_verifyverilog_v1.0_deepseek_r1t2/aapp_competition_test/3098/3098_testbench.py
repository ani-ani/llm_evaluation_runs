import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 32
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

async def write_real_array(dut, array_name, values):
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = val
        return
    except (AttributeError, TypeError):
        pass
    for i, val in enumerate(values):
        port_name = f'{array_name}_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f'Cannot find array port: {array_name}[{i}] or {port_name}')

async def read_real_array(dut, array_name, size):
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(float(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    for i in range(size):
        port_name = f'{array_name}_{i}'
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(float(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

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
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_expected_area(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    test_cases = [
        (4, 3, [0.0, 1.0, 2.0, 1.0], [0.0, 1.0, 1.0, 0.0], 0.5),
        (5, 5, [0.0, 4.0, 4.0, 3.0, -2.0], [4.0, 2.0, 1.0, -1.0, 4.0], 12.5),
        (5, 3, [-1.20, 3.30, 3.10, 2.00, -4.40], [2.80, 2.40, -0.80, -4.60, -0.50], 12.433),
    ]
    passed = 0
    failed = 0
    for i, (n, k, x_coords, y_coords, expected) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: n={n}, k={k}')
        try:
            if has_signal(dut, 'n'):
                dut.n.value = n
            else:
                raise TestFailure('Signal n not found')
            if has_signal(dut, 'k'):
                dut.k.value = k
            else:
                raise TestFailure('Signal k not found')
            await write_real_array(dut, 'x', x_coords)
            await write_real_array(dut, 'y', y_coords)
            await start_computation(dut)
            await wait_for_done(dut)
            if not is_value_defined(dut.result.value):
                raise TestFailure('Result is undefined (X/Z)')
            result = float(dut.result.value)
            if abs(result - expected) > 1e-6:
                raise TestFailure(f'Expected {expected}, got {result}')
            cocotb.log.info(f'  PASS: result = {result:.8f}')
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
    cocotb.log.info('='*50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')