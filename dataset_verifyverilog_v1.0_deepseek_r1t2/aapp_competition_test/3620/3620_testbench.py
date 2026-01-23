import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
async def test_graph_coloring(dut):
    '''Test the graph_coloring module with tree colorings.'''
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    # Reset
    await reset_dut(dut)
    # Test cases: (N, k, P, expected_result)
    test_cases = [
        (1, 2, 10000, 2 % 10000),
        (2, 2, 10000, 2 * 1 % 10000),
        (3, 2, 10000, 2 * 1 * 1 % 10000),
        (3, 4, 13, 4 * 3 * 3 % 13),
        (8, 5, 100, (5 * pow(4, 7, 100)) % 100),
    ]
    passed = 0
    failed = 0
    for i, (N, k, P, expected) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: N={N}, k={k}, P={P}, expected={expected}')
        dut.N.value = N
        dut.k.value = k
        dut.P.value = P
        await start_computation(dut)
        await wait_for_done(dut)
        if not is_value_defined(dut.result.value):
            dut._log.error(f'Test {i+1} FAIL: result is undefined')
            failed += 1
            continue
        result = int(dut.result.value)
        if result != expected:
            dut._log.error(f'Test {i+1} FAIL: expected {expected}, got {result}')
            failed += 1
        else:
            dut._log.info(f'Test {i+1} PASS: result = {result}')
            passed += 1
        await RisingEdge(dut.clk)
    dut._log.info('='*50)
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')