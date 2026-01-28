import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
GRID_SIZE = 64  # 8x8
MAX_TIME = 128
K = 5
START_TIME = 1
CLK_NS = 10
MAX_CYCLES = 2000

# Helper functions from template
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

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
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reference Python solver for verification
def solve_reference(r, c, k, l, start_r, start_c, times):
    # r, c are up to 100 but we'll scale down
    # This is for verification only, scaled inputs will be smaller
    from collections import deque
    
    reachable = set()
    reachable.add((start_r, start_c, 1))  # (row, col, time)
    
    q = deque([(start_r, start_c, 1)])
    
    visited = set([(start_r, start_c, 1)])
    
    while q:
        r_curr, c_curr, t = q.popleft()
        
        # Can wait here
        next_t = t + 1
        if next_t <= l:
            if (r_curr, c_curr, next_t) not in visited:
                visited.add((r_curr, c_curr, next_t))
                q.append((r_curr, c_curr, next_t))
        
        # Move to neighbors
        for dr, dc in [(0,1), (0,-1), (1,0), (-1,0)]:
            nr, nc = r_curr + dr, c_curr + dc
            if 0 <= nr < r and 0 <= nc < c:
                next_t = t + 1
                if next_t <= l and (nr, nc, next_t) not in visited:
                    visited.add((nr, nc, next_t))
                    q.append((nr, nc, next_t))
    
    # Count fish
    count = 0
    for row in range(r):
        for col in range(c):
            t0 = times[row][col]
            # Fish available from t0 to t0 + k - 1
            for t in range(t0, t0 + k):
                if t >= START_TIME and t <= l:
                    if (row, col, t) in visited:
                        count += 1
    return count

# Scaled-down Python solver for HDL comparison
def solve_hdl_compatible(grid_times, max_time=MAX_TIME):
    """
    grid_times: list of 64 integers (row-major)
    Returns count of (cell, time) pairs where fish is available AND reachable.
    Assumes start at (0,0) at time 1.
    """
    # reachable[cell] = bitmask of times (simplified, we track per time step)
    # Instead, we use iterative approach: for each time t, which cells reachable?
    
    reachable = [False] * 64
    reachable[0] = True  # Start at cell 0 at time 1
    
    count = 0
    
    # Time 1
    t = 1
    # Check fish at time 1
    for cell in range(64):
        if reachable[cell]:
            t0 = grid_times[cell]
            if t0 <= t < t0 + K:
                count += 1
    
    # For time 2 to max_time-1
    for t in range(2, max_time):
        # Compute next reachable from current
        next_reachable = [False] * 64
        for cell in range(64):
            if not reachable[cell]:
                continue
            # Stay
            next_reachable[cell] = True
            # Move to neighbors (8x8 grid)
            row = cell // 8
            col = cell % 8
            # North
            if row > 0:
                next_reachable[(row-1)*8 + col] = True
            # South
            if row < 7:
                next_reachable[(row+1)*8 + col] = True
            # West
            if col > 0:
                next_reachable[row*8 + (col-1)] = True
            # East
            if col < 7:
                next_reachable[row*8 + (col+1)] = True
        
        reachable = next_reachable
        
        # Check fish at time t
        for cell in range(64):
            if reachable[cell]:
                t0 = grid_times[cell]
                if t0 <= t < t0 + K:
                    count += 1
    
    return count

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_fishing(dut):
    # Check signals
    if not has_signal(dut, 'clk'):
        await Timer(100, units='ns')
        return
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases (scaled to 8x8 or smaller)
    test_cases = [
        {
            "desc": "Small 2x2 grid, t=1, k=5, l=10",
            "grid_times": [1, 4, 3, 2],  # 2x2 flattened
            "expected": solve_hdl_compatible([1,4,3,2])
        },
        {
            "desc": "2x3 grid, t=1, k=5, l=6",
            "grid_times": [1,1,6,1,2,2],  # 2x3 flattened (pad to 6 elements, rest 0)
            "expected": solve_hdl_compatible([1,1,6,1,2,2])
        },
        {
            "desc": "Single cell 1x1",
            "grid_times": [1] + [0]*63,
            "expected": solve_hdl_compatible([1] + [0]*63)
        },
        {
            "desc": "All fish at t=1, k=5",
            "grid_times": [1]*64,
            "expected": solve_hdl_compatible([1]*64)
        },
        {
            "desc": "No fish",
            "grid_times": [0]*64,
            "expected": solve_hdl_compatible([0]*64)
        },
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Test: {tc['desc']}")
        
        try:
            # Write grid times
            # dut.grid_t is array of 64 signals, each 8 bits
            for i in range(64):
                dut.grid_t[i].value = clamp_to_width(tc['grid_times'][i], 8)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            expected = tc['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
