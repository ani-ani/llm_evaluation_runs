import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MAX_LEN = 16
DATA_WIDTH = 128
CLK_PERIOD_NS = 10

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f'Timeout after {max_cycles} cycles')

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

def encode_pattern(pattern):
    mapping = {'L': 0, 'R': 1, 'P': 2, '*': 3}
    packed = 0
    for i, ch in enumerate(pattern):
        packed |= mapping[ch] << (2 * i)
    return packed, len(pattern)

def compute_expected(pattern):
    count = 1
    total = 1
    for ch in pattern:
        if ch == 'L':
            total = total * 2
        elif ch == 'R':
            total = total * 2 + count
        elif ch == 'P':
            pass
        elif ch == '*':
            total = total * 5 + count
            count = count * 3
    return total

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_walk_sum(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    patterns = ['P*P', 'L*R', '**', 'L', 'R', 'P', 'L*', 'LRP', 'LL*PP']
    for pattern in patterns:
        if len(pattern) > MAX_LEN:
            continue
        cocotb.log.info(f'Testing: {pattern}')
        expected = compute_expected(pattern)
        packed, length = encode_pattern(pattern)
        dut.string_packed.value = packed
        dut.length.value = length
        await start_computation(dut)
        await wait_for_done(dut)
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f'Expected {expected}, got {result}')
        cocotb.log.info(f'  PASS')
    cocotb.log.info('=' * 50)
    cocotb.log.info('All tests passed')