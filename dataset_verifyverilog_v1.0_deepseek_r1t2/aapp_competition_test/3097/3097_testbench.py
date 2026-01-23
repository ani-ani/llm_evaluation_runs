import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration matching Verilog parameters
DATA_WIDTH = 32
MAX_ROWS = 200
MAX_STEPS = 20
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    if not has_signal(dut, 'done'):
        await Timer(100, units='ns')
        return True
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout after {max_cycles} cycles')

async def start_computation(dut):
    if has_signal(dut, 'start'):
        dut.start.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        dut.start.value = 0
    else:
        await Timer(10, units='ns')

# Reference implementation
def reverse_digits(n):
    if n == 0:
        return 0
    rev = 0
    while n > 0:
        rev = rev * 10 + (n % 10)
        n //= 10
    return rev

def count_reference(A, B):
    count = 0
    for i in range(1, min(B, MAX_ROWS) + 1):
        val = i
        for _ in range(MAX_STEPS):
            if A <= val <= B:
                count += 1
            if val > B:
                break
            val = val + reverse_digits(val)
    return count

@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_table_counter(dut):
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (1, 10, count_reference(1, 10), 'Range 1-10'),
        (5, 8, count_reference(5, 8), 'Range 5-8'),
        (17, 144, count_reference(17, 144), 'Range 17-144'),
        (121, 121, count_reference(121, 121), 'Single 121'),
        (89, 98, count_reference(89, 98), 'Range 89-98'),
        (1, 100, count_reference(1, 100), 'Range 1-100'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (A, B, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f'\\nTest {i+1}: {desc}')
        try:
            if has_signal(dut, 'A'):
                dut.A.value = A
            if has_signal(dut, 'B'):
                dut.B.value = B
            
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not has_signal(dut, 'result'):
                raise TestFailure('Result signal missing')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure('Result undefined')
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f'Expected {expected}, got {result}')
            
            cocotb.log.info(f'  PASS: {result}')
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
    
    cocotb.log.info('\\n' + '='*50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} passed')
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')