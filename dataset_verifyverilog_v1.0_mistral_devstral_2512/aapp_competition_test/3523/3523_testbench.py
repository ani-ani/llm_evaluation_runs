import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_coin_optimizer(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (P, N1, N5, N10, N25, expected_result, description)
    # expected_result is None for impossible cases
    test_cases = [
        (13, 3, 2, 1, 1, 5, 'Example 1: 13 cents with 3,2,1,1'),
        (13, 2, 2, 1, 1, None, 'Example 2: impossible'),
        (255, 255, 255, 255, 255, 255, 'All coins available, P=255, use 255 ones'),
        (30, 25, 1, 0, 0, 26, '30 cents with 25 ones and one 5-cent'),
        (1, 1, 0, 0, 0, 1, '1 cent with one 1-cent'),
        (5, 0, 1, 0, 0, 1, '5 cents with one 5-cent'),
        (5, 5, 0, 0, 0, 5, '5 cents with five 1-cents'),
        (10, 0, 0, 1, 0, 1, '10 cents with one 10-cent'),
        (10, 10, 0, 0, 0, 10, '10 cents with ten 1-cents'),
        (25, 0, 0, 0, 1, 1, '25 cents with one 25-cent'),
        (25, 25, 0, 0, 0, 25, '25 cents with twenty-five 1-cents'),
        (50, 0, 0, 0, 2, 2, '50 cents with two 25-cents'),
        (50, 0, 0, 5, 0, 5, '50 cents with five 10-cents'),
        (50, 0, 10, 0, 0, 10, '50 cents with ten 5-cents'),
        (50, 50, 0, 0, 0, 50, '50 cents with fifty 1-cents'),
        (100, 100, 0, 0, 0, 100, '100 cents with 100 ones'),
        (100, 0, 20, 0, 0, 20, '100 cents with twenty 5-cents'),
        (100, 0, 0, 10, 0, 10, '100 cents with ten 10-cents'),
        (100, 0, 0, 0, 4, 4, '100 cents with four 25-cents'),
        (99, 99, 0, 0, 0, 99, '99 cents with 99 ones'),
        (99, 0, 0, 0, 3, None, '99 cents with only 75 cents in 25s -> impossible'),
        (255, 0, 0, 0, 10, 10, '255 cents with 10 quarters (250) and no 1s -> cannot pay exactly'),
        (255, 5, 0, 0, 10, 15, '255 cents: 10 quarters (250) + 5 ones -> 15 coins'),
        (255, 4, 1, 0, 10, 15, '255: 10q + 4 ones + 1 five -> 15 coins'),
        (0, 0, 0, 0, 0, 0, 'P=0 (edge case, but P>=1 normally)'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (P, N1, N5, N10, N25, expected, desc) in enumerate(test_cases):
        if P == 0:
            continue
        cocotb.log.info(f'Test {i+1}: {desc}')
        
        dut.P.value = clamp_to_width(P, DATA_WIDTH)
        dut.N1.value = clamp_to_width(N1, DATA_WIDTH)
        dut.N5.value = clamp_to_width(N5, DATA_WIDTH)
        dut.N10.value = clamp_to_width(N10, DATA_WIDTH)
        dut.N25.value = clamp_to_width(N25, DATA_WIDTH)
        
        await start_computation(dut)
        await wait_for_done(dut)
        
        valid = int(dut.valid.value)
        result = int(dut.result.value) if valid else None
        
        if expected is None:
            if valid == 0:
                cocotb.log.info(f'  PASS: correctly detected impossible (valid=0)')
                passed += 1
            else:
                cocotb.log.error(f'  FAIL: expected impossible, but got valid=1, result={result}')
                failed += 1
        else:
            if valid == 1 and result == expected:
                cocotb.log.info(f'  PASS: result={result}')
                passed += 1
            else:
                cocotb.log.error(f'  FAIL: expected {expected}, got valid={valid}, result={result}')
                failed += 1
    
    cocotb.log.info('='*50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')