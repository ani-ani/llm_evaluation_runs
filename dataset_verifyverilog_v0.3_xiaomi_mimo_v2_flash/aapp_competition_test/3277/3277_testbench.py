import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
N_WIDTH = 4
K_WIDTH = 4
S_WIDTH = 5
RESULT_WIDTH = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

async def write_array(dut, values, max_size=16):
    for i in range(max_size):
        port_name = f'A{i}'
        if i < len(values):
            val = values[i]
        else:
            val = 0
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f'Signal {port_name} not found')

async def read_result(dut):
    if is_value_defined(dut.result.value):
        return int(dut.result.value)
    else:
        raise TestFailure('Result is undefined')

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

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_smooth_array(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (3, 3, 5, [1,2,3], 1),
        (6, 3, 5, [1,2,3,3,2,1], 3),
        (5, 1, 5, [1,2,3,4,5], 4),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, K, S, arr, expected) in enumerate(test_cases):
        dut._log.info(f'Test case {i+1}: N={N}, K={K}, S={S}, arr={arr}')
        dut.N.value = N
        dut.K.value = K
        dut.S.value = S
        await write_array(dut, arr, max_size=16)
        await start_computation(dut)
        
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            dut._log.error(f'Test {i+1} failed: {e}')
            failed += 1
            continue
        
        try:
            result = await read_result(dut)
        except TestFailure as e:
            dut._log.error(f'Test {i+1} failed: {e}')
            failed += 1
            continue
        
        if result != expected:
            dut._log.error(f'Test {i+1} failed: expected {expected}, got {result}')
            failed += 1
        else:
            dut._log.info(f'Test {i+1} passed: result = {result}')
            passed += 1
    
    dut._log.info('='*50)
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')
