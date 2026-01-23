import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import cocotb.log

# CONFIGURATION
DATA_WIDTH = 2
ROW_COL_WIDTH = 3
N = 4
MAX_TARGETS = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 50

# HELPER FUNCTIONS

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

# SOLVE FUNCTION
def solve(a):
    n = len(a)
    ans = []
    one = []
    tt = []
    for i in range(n-1, -1, -1):
        val = a[i]
        if val == 0:
            continue
        if val == 1:
            ans.append((i+1, i+1))
            one.append((i+1, i+1))
        elif val == 2:
            if not one:
                return None
            row, _ = one.pop()
            ans.append((row, i+1))
            tt.append((row, i+1))
        elif val == 3:
            if tt:
                row, col = tt.pop()
                ans.append((i+1, col))
                ans.append((i+1, i+1))
                tt.append((i+1, i+1))
            elif one:
                row, col = one.pop()
                ans.append((i+1, col))
                ans.append((i+1, i+1))
                tt.append((i+1, i+1))
            else:
                return None
    return ans

# MAIN TEST
@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_boomerang(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    captured = []
    async def monitor():
        while True:
            await RisingEdge(dut.target_valid)
            if int(dut.target_valid) == 1:
                row = int(dut.target_row)
                col = int(dut.target_col)
                captured.append((row, col))
    cocotb.start_soon(monitor())
    
    test_cases = [
        ([0,0,0,0], 'All zeros'),
        ([1,1,1,1], 'All ones'),
        ([2,2,2,2], 'All twos'),
        ([3,3,3,3], 'All threes'),
        ([2,0,3,0], 'Two and three'),
        ([1,2,3,1], 'Mixed'),
        ([3,2,1,0], 'Decreasing'),
        ([2,1,2,3], 'Complex'),
    ]
    
    for i, (a_list, desc) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: {desc} - a={a_list}')
        captured.clear()
        
        dut.a0.value = a_list[0]
        dut.a1.value = a_list[1]
        dut.a2.value = a_list[2]
        dut.a3.value = a_list[3]
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        expected = solve(a_list)
        valid = int(dut.valid.value)
        
        if expected is None:
            if valid:
                raise TestFailure(f'Expected invalid, but valid=1')
            if len(captured) > 0:
                raise TestFailure(f'Expected no targets, but got {len(captured)}')
            dut._log.info('  PASS (correctly invalid)')
        else:
            if not valid:
                raise TestFailure(f'Expected valid, but valid=0')
            await Timer(1, units='ns')
            if len(captured) != len(expected):
                raise TestFailure(f'Expected {len(expected)} targets, got {len(captured)}')
            for j, (exp_row, exp_col) in enumerate(expected):
                if j >= len(captured):
                    raise TestFailure(f'Missing target {j}')
                row, col = captured[j]
                if (row, col) != (exp_row, exp_col):
                    raise TestFailure(f'Target {j}: expected ({exp_row},{exp_col}), got ({row},{col})')
            dut._log.info('  PASS')
    
    dut._log.info('All tests passed')