import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 5
ARRAY_SIZE = 16
LEN_WIDTH = 4
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

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

def char_to_index(c):
    return ord(c) - ord('a')

async def write_string(dut, s, length):
    values = [char_to_index(c) for c in s]
    for i in range(ARRAY_SIZE):
        port_name = f'arr_{i}'
        if hasattr(dut, port_name):
            if i < length:
                getattr(dut, port_name).value = values[i]
            else:
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f'Port {port_name} not found')
    dut.len.value = length

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if hasattr(dut, 'start'):
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
async def test_secret_message(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ('aaabb', 6, 'Example 1'),
        ('usaco', 1, 'Example 2'),
        ('lol', 2, 'Example 3'),
        ('cc', 2, 'Two same'),
        ('qqq', 3, 'Three same'),
        ('aaaa', 6, 'Four a'),
        ('zy', 1, 'Two diff'),
        ('a', 1, 'Single'),
        ('ab', 1, 'Two diff pair'),
        ('llllloooolllll', 45, 'Long pattern'),
    ]
    
    passed = 0
    failed = 0
    
    for test_str, expected, description in test_cases:
        cocotb.log.info(f'Testing: {description}')
        
        if len(test_str) > 16:
            cocotb.log.warning(f'  SKIPPED: String too long ({len(test_str)} > 16)')
            continue
        
        try:
            await write_string(dut, test_str, len(test_str))
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure('Result is undefined (X/Z)')
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f'Expected {expected}, got {result}')
            
            cocotb.log.info(f'  PASS: result = {result}')
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
    
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')