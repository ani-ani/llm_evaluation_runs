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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

def compute_expected(n):
    values = []
    for i in range(16, -1, -1):
        if (n >> i) & 1:
            values.append(i + 1)
    return values

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_slime_combiner(dut):
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        (1, [1]),
        (2, [2]),
        (3, [2, 1]),
        (8, [4]),
        (100000, [17,16,11,10,8,6]),
        (12345, [14,13,6,5,4,1]),
        (32, [6]),
        (70958, [17,13,11,9,6,4,3,2]),
        (97593, [17,15,14,13,12,11,9,6,5,4,1]),
        (91706, [17,15,14,11,10,6,5,4,2]),
        (85371, [17,15,12,11,9,7,6,5,4,2,1]),
        (97205, [17,15,14,13,12,10,9,8,6,5,3,1]),
        (34768, [16,11,10,9,8,7,5]),
        (12705, [14,13,9,8,6,1]),
        (30151, [15,14,13,11,9,8,7,3,2,1]),
        (4974, [13,10,9,7,6,4,3,2]),
        (32728, [15,14,13,12,11,10,9,8,7,5,4]),
        (8192, [14]),
        (65536, [17]),
        (32, [6]),
        (256, [9]),
        (4096, [13]),
        (33301, [16,10,5,3,1]),
        (16725, [15,9,7,5,3,1]),
        (149, [8,5,3,1]),
        (16277, [14,13,12,11,10,9,8,5,3,1]),
        (99701, [17,16,11,9,7,6,5,3,1]),
    ]
    
    for n_val, expected in test_cases:
        dut.n.value = n_val
        if is_sequential:
            await Timer(100, units='ns')
        else:
            await Timer(10, units='ns')
        
        if not is_value_defined(dut.count.value):
            raise TestFailure(f'Count undefined for n={n_val}')
        count = int(dut.count.value)
        
        actual = []
        for i in range(17):
            if not is_value_defined(dut.values[i].value):
                raise TestFailure(f'Value at index {i} undefined for n={n_val}')
            val = int(dut.values[i].value)
            if i < count:
                actual.append(val)
            else:
                if val != 0:
                    raise TestFailure(f'Index {i} beyond count {count} has non-zero value {val} for n={n_val}')
        
        if actual != expected:
            raise TestFailure(f'For n={n_val}, expected {expected}, got {actual}')
        dut._log.info(f'n={n_val}: PASS')
    
    dut._log.info('All tests passed!')