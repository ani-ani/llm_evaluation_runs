import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
GRID_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 50000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def python_reference(h_flat, v_flat, grid_size=16):
    """Reference Python implementation for 16x16 grid"""
    max_comp = 0
    # Pre-calculate all possible heights for t=0..255
    heights_t = []
    for t in range(256):
        h_at_t = []
        for i in range(grid_size * grid_size):
            # Clamp to 8-bit (wrap around)
            h_at_t.append(clamp_to_width(h_flat[i] + v_flat[i] * t, DATA_WIDTH))
        heights_t.append(h_at_t)
    
    # For each time step
    for t in range(256):
        h_curr = heights_t[t]
        visited = [[False] * grid_size for _ in range(grid_size)]
        
        for r in range(grid_size):
            for c in range(grid_size):
                if not visited[r][c]:
                    # BFS for this component
                    target_h = h_curr[r * grid_size + c]
                    queue = [(r, c)]
                    visited[r][c] = True
                    comp_size = 0
                    
                    while queue:
                        cr, cc = queue.pop(0)
                        comp_size += 1
                        
                        # 4 neighbors
                        for dr, dc in [(-1,0), (1,0), (0,-1), (0,1)]:
                            nr, nc = cr + dr, cc + dc
                            if 0 <= nr < grid_size and 0 <= nc < grid_size:
                                nidx = nr * grid_size + nc
                                if not visited[nr][nc] and h_curr[nidx] == target_h:
                                    visited[nr][nc] = True
                                    queue.append((nr, nc))
                    
                    if comp_size > max_comp:
                        max_comp = comp_size
    return max_comp

@cocotb.test(timeout_time=60, timeout_unit="ms")
async def test_grid_connected_components(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test 1: Simple 3x3 case (but we use 16x16 with mostly zeros)
    # Input 1: 3x3 from problem (padded to 16x16)
    h1 = [
        1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        3, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        5, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ] + [0] * (256 - 9)
    v1 = [
        3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ] + [0] * (256 - 9)
    
    # Expected output: 7 (from problem)
    expected1 = 7
    
    # Test 2: 2x2 case (padded to 16x16)
    # From second example input
    h2 = [
        3, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ] + [0] * (256 - 4)
    v2 = [
        2, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        2, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ] + [0] * (256 - 4)
    
    expected2 = 3
    
    test_cases = [
        (h1, v1, expected1, "3x3 from problem (padded)"),
        (h2, v2, expected2, "2x2 from problem (padded)")
    ]
    
    passed = 0
    failed = 0
    
    for i, (h_vals, v_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write h array (256 elements)
            for idx, val in enumerate(h_vals):
                dut.h[idx].value = clamp_to_width(val, DATA_WIDTH)
            
            # Write v array (256 elements)
            for idx, val in enumerate(v_vals):
                dut.v[idx].value = clamp_to_width(val, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASSED: {result}")
            
            if is_seq:
                await Timer(100, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")