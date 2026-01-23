import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
MAX_VILLAGES = 2
MAX_MINIONS = 8
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
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Test cases
test_cases = [
    {
        "n": 1, "m": 3, "R": 3,
        "villages": [(0, 0, 1)],
        "minions": [(3, 3), (-3, 3), (3, -3)],
        "expected": 1,
        "description": "Sample 1"
    },
    {
        "n": 1, "m": 5, "R": 3,
        "villages": [(0, 0, 1)],
        "minions": [(3, 3), (-3, 3), (3, -3), (3, 0), (0, 3)],
        "expected": 3,
        "description": "Sample 2"
    },
    {
        "n": 4, "m": 10, "R": 100,
        "villages": [(0, 0, 3), (10, 0, 3), (10, 10, 3), (0, 10, 3)],
        "minions": [(0, 4), (0, 5), (0, 6), (5, 3), (5, -3), (5, 5), (6, 7), (3, 6), (10, 4), (8, 4)],
        "expected": 5,
        "description": "Sample 3"
    }
]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_minions_attack(dut):
    """Main test for max_minions_attack module."""
    
    # Detect sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for case in test_cases:
        n, m, R = case['n'], case['m'], case['R']
        villages = case['villages']
        minions = case['minions']
        expected = case['expected']
        desc = case['description']
        
        cocotb.log.info(f"Running test: {desc}")
        
        # Set n, m, R
        if has_signal(dut, 'n'):
            dut.n.value = n
        if has_signal(dut, 'm'):
            dut.m.value = m
        if has_signal(dut, 'R'):
            dut.R.value = R
        
        # Set villages
        for i in range(MAX_VILLAGES):
            if i < n:
                vx, vy, vr = villages[i]
                getattr(dut, f'village_x_{i}').value = vx
                getattr(dut, f'village_y_{i}').value = vy
                getattr(dut, f'village_r_{i}').value = vr
            else:
                getattr(dut, f'village_x_{i}').value = 0
                getattr(dut, f'village_y_{i}').value = 0
                getattr(dut, f'village_r_{i}').value = 0
        
        # Set minions
        for j in range(MAX_MINIONS):
            if j < m:
                mx, my = minions[j]
                getattr(dut, f'minion_x_{j}').value = mx
                getattr(dut, f'minion_y_{j}').value = my
            else:
                getattr(dut, f'minion_x_{j}').value = 0
                getattr(dut, f'minion_y_{j}').value = 0
        
        await Timer(10, units='ns')
        
        if is_sequential:
            await start_computation(dut)
            await wait_for_done(dut)
            if not is_value_defined(dut.max_count.value):
                raise TestFailure(f"max_count is undefined")
            result = int(dut.max_count.value)
        else:
            await Timer(100, units='ns')
            result = int(dut.max_count.value)
        
        if result == expected:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")