import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MAX_ROWS = 8
MAX_COLS = 8
DATA_WIDTH = 2
MAX_PIECES = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

def pack_board(board_grid, rows, cols, data_width):
    result = 0
    for i in range(rows):
        for j in range(cols):
            cell = board_grid[i][j]
            if cell == 'M':
                val = 1
            elif cell == 'S':
                val = 2
            else:
                val = 0
            pos = (i * cols + j) * data_width
            result |= (val << pos)
    return result

def parse_board_str(board_str):
    lines = board_str.strip().split('\n')
    rows, cols = map(int, lines[0].split())
    grid = [list(line.strip()) for line in lines[1:1+rows]]
    return rows, cols, grid

def create_full_board(parsed_grid, rows, cols, max_rows, max_cols):
    full_grid = [['.' for _ in range(max_cols)] for _ in range(max_rows)]
    for i in range(rows):
        for j in range(cols):
            if i < max_rows and j < max_cols:
                full_grid[i][j] = parsed_grid[i][j]
    return full_grid

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

@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_spread_calculator(dut):
    '''Test spread calculator with example cases.'''
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    else:
        pass
    
    test_cases = [
        ('2 3\nSMS\nMMS\n', 3, 5),
        ('2 3\nS.M\nM..\n', 2, 0),
        ('4 5\nM....\n..S.M\nSS..S\n.M...\n', 10, 13),
    ]
    
    passed = 0
    failed = 0
    
    for i, (board_str, expected_m, expected_s) in enumerate(test_cases):
        dut._log.info(f'Running test case {i+1}')
        
        rows, cols, grid = parse_board_str(board_str)
        full_grid = create_full_board(grid, rows, cols, MAX_ROWS, MAX_COLS)
        packed = pack_board(full_grid, MAX_ROWS, MAX_COLS, DATA_WIDTH)
        
        dut.board_packed.value = packed
        
        if not has_signal(dut, 'clk'):
            await Timer(10, units='ns')
        
        if has_signal(dut, 'clk'):
            await start_computation(dut)
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        if not is_value_defined(dut.mirko_spread.value) or not is_value_defined(dut.slavko_spread.value):
            raise TestFailure(f'Output undefined in test {i+1}')
        
        mirko_spread = int(dut.mirko_spread.value)
        slavko_spread = int(dut.slavko_spread.value)
        
        if mirko_spread != expected_m or slavko_spread != expected_s:
            dut._log.error(f'Test {i+1} FAILED: Expected ({expected_m}, {expected_s}), got ({mirko_spread}, {slavko_spread})')
            failed += 1
        else:
            dut._log.info(f'Test {i+1} PASSED')
            passed += 1
    
    dut._log.info('='*50)
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')