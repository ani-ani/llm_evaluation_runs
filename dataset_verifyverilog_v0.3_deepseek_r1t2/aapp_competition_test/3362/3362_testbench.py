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
    return min(max_val, max(0, value))

def pack_array(values, element_bits=4):
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

def parse_map(input_str):
    lines = input_str.strip().split(chr(10))
    first_line = lines[0].split()
    A = int(first_line[0])
    F = int(first_line[1])
    second_line = lines[1].split()
    L = int(second_line[0])
    W = int(second_line[1])
    map_lines = lines[2:2+L]
    return A, F, L, W, map_lines

def extract_safe_tiles(L, W, map_lines):
    safe_tiles = []
    start_idx = 0
    goal_idx = 0
    for r in range(L):
        for c in range(W):
            ch = map_lines[r][c]
            if ch == 'S':
                safe_tiles.append((r, c))
            elif ch == 'G':
                safe_tiles.append((r, c))
    for r in range(L):
        for c in range(W):
            ch = map_lines[r][c]
            if ch == 'W':
                safe_tiles.append((r, c))
    rows = []
    cols = []
    for idx, (r, c) in enumerate(safe_tiles):
        rows.append(r)
        cols.append(c)
        if map_lines[r][c] == 'S':
            start_idx = idx
        if map_lines[r][c] == 'G':
            goal_idx = idx
    N = len(safe_tiles)
    if N > 8:
        raise ValueError('Too many safe tiles')
    while len(rows) < 8:
        rows.append(0)
        cols.append(0)
    return rows, cols, start_idx, goal_idx, N

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_lava_game(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_inputs = [
        '2 3\n4 4\nWWWW\nWSBB\nWWWW\nWBWG\n',
        '1 1\n1 2\nGS\n'
    ]
    expected_outputs = [
        'GO FOR IT\n',
        'SUCCESS\n'
    ]
    
    for test_idx, (input_str, expected_str) in enumerate(zip(test_inputs, expected_outputs)):
        dut._log.info('Test case ' + str(test_idx+1))
        A, F, L, W, map_lines = parse_map(input_str)
        rows, cols, start_idx, goal_idx, N = extract_safe_tiles(L, W, map_lines)
        rows_packed = pack_array(rows, 4)
        cols_packed = pack_array(cols, 4)
        A_val = clamp_to_width(A, 8)
        F_val = clamp_to_width(F, 8)
        dut.N.value = N
        dut.start_idx.value = start_idx
        dut.goal_idx.value = goal_idx
        dut.A.value = A_val
        dut.F.value = F_val
        dut.rows_data.value = rows_packed
        dut.cols_data.value = cols_packed
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        max_cycles = 1000
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure('Timeout on test ' + str(test_idx+1))
        
        if not is_value_defined(dut.result.value):
            raise TestFailure('Result undefined on test ' + str(test_idx+1))
        
        result_val = int(dut.result.value)
        result_map = {
            0: 'SUCCESS\n',
            1: 'GO FOR IT\n',
            2: 'NO CHANCE\n',
            3: 'NO WAY\n'
        }
        actual_output = result_map.get(result_val, 'UNKNOWN (' + str(result_val) + ')\n')
        if actual_output != expected_str:
            raise TestFailure('Test ' + str(test_idx+1) + ': expected ' + expected_str.strip() + ', got ' + actual_output.strip())
        dut._log.info('Test ' + str(test_idx+1) + ' passed')
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info('All tests passed!')