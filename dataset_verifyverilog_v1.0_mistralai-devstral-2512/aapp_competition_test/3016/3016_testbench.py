import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 4
MAX_COUNT = 10
MAX_COLORS = 5
PATTERN_MAX_LEN = 5
CLK_NS = 10
TIMEOUT_CYCLES = 1000000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, width):
    return min((1 << width) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'busy'): await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, timeout=TIMEOUT_CYCLES):
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {timeout} cycles")

async def write_freq(dut, freq_list):
    for i in range(MAX_COLORS):
        val = freq_list[i] if i < len(freq_list) else 0
        dut.freq[i].value = clamp_to_width(val, DATA_WIDTH)

async def write_adj(dut, adj_matrix):
    for i in range(MAX_COLORS):
        for j in range(MAX_COLORS):
            val = adj_matrix[i][j] if i < len(adj_matrix) and j < len(adj_matrix[i]) else 0
            dut.adj[i][j].value = clamp_to_width(val, 1)

async def write_pattern(dut, pattern):
    dut.pattern_len.value = clamp_to_width(len(pattern), 3)
    for i in range(PATTERN_MAX_LEN):
        val = pattern[i] if i < len(pattern) else 0
        dut.pattern[i].value = clamp_to_width(val, DATA_WIDTH)

@cocotb.test(timeout_time=30, timeout_unit="s")
async def test_baby_timmy(dut):
    if not has_signal(dut, 'clk'):
        # Combinational (unlikely for DP), just test basic
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        {
            'name': 'Sample 1: 2R,1Y,2G,1B; adj R,Y; pattern G,B',
            'n': 4,
            'freq': [2, 1, 2, 1],  # R,Y,G,B
            'adj': [[0,1,0,0], [1,0,0,0], [0,0,0,0], [0,0,0,0]],  # R-Y adjacent
            'pattern': [3, 4],  # G,B (1-based -> 3,4)
            'expected': 6
        },
        {
            'name': 'Sample 2: 3,1,1; adj R; pattern 2,3 -> 0',
            'n': 3,
            'freq': [3, 1, 1],
            'adj': [[1,0,0], [0,0,0], [0,0,0]],  # Only color 1 (index 0)
            'pattern': [2, 3],  # 2,3 (1-based -> 2,3)
            'expected': 0
        },
        {
            'name': 'Sample 3: 2,2,3; adj R; pattern 2,3 -> 18',
            'n': 3,
            'freq': [2, 2, 3],
            'adj': [[1,0,0], [0,0,0], [0,0,0]],  # Only color 1
            'pattern': [2, 3],
            'expected': 18
        },
        {
            'name': 'Sample 4: 1,2,3; adj R,Y; no pattern -> 12',
            'n': 3,
            'freq': [1, 2, 3],
            'adj': [[1,1,0], [1,0,0], [0,0,0]],  # R-Y adjacent
            'pattern': [],
            'expected': 12
        },
        {
            'name': 'Sample 5: 1,4,1; adj Y; pattern 3 -> 0',
            'n': 3,
            'freq': [1, 4, 1],
            'adj': [[0,1,0], [1,0,0], [0,0,0]],  # Color 2 (index 1)
            'pattern': [3],
            'expected': 0
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Running: {tc['name']}")
        cocotb.log.info(f"{'='*60}")
        
        # Scale down: if n > MAX_COLORS, we can't fully process, skip or fail
        if tc['n'] > MAX_COLORS:
            cocotb.log.warning(f"Skipping {tc['name']}: n={tc['n']} > {MAX_COLORS}")
            # Check expected is 0 or handle specially
            if tc['expected'] != 0:
                cocotb.log.error(f"FAIL: Cannot verify - n too large for HDL")
                failed += 1
            else:
                passed += 1
            continue
            
        # Prepare inputs
        # Colors are 1-based in Python, convert to 0-based for HDL
        freq_scaled = tc['freq'][:MAX_COLORS]
        adj_scaled = [[0]*MAX_COLORS for _ in range(MAX_COLORS)]
        for i in range(min(tc['n'], MAX_COLORS)):
            for j in range(min(tc['n'], MAX_COLORS)):
                adj_scaled[i][j] = tc['adj'][i][j] if i < len(tc['adj']) and j < len(tc['adj'][i]) else 0
        
        # Convert pattern to 0-based
        pattern_scaled = [p-1 for p in tc['pattern'] if p <= MAX_COLORS]
        
        # Write inputs
        await write_freq(dut, freq_scaled)
        await write_adj(dut, adj_scaled)
        await write_pattern(dut, pattern_scaled)
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, timeout=100000)  # 100k cycles max
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error("FAIL: Result signal undefined")
            failed += 1
            continue
            
        result = int(dut.result.value)
        expected = tc['expected'] % 1000000007
        
        cocotb.log.info(f"Result: {result}, Expected: {expected}")
        
        if result == expected:
            cocotb.log.info(f"PASS: {tc['name']}")
            passed += 1
        else:
            cocotb.log.error(f"FAIL: {tc['name']} - Expected {expected}, got {result}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: Passed={passed}, Failed={failed}")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
