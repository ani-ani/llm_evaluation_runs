import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random
import math

# Helpers
DATA_WIDTH = 16
MAX_N = 8  # Reduced for simulation speed (2^8 * 8^2 = 16k cycles)
MAX_M = 8
MAX_CYCLES = 50000
CLK_NS = 10

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    # Handle signed ranges
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    if v > max_val: return max_val
    if v < min_val: return min_val
    return v

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'din_valid'): dut.din_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python reference implementation for verification
def solve_python(malls, m):
    # malls: list of (x, y, type)
    n = len(malls)
    if n == 0: return 0
    
    # DP: dp[mask][i] = min vertical moves to visit set 'mask' ending at node 'i'
    INF = 10**9
    dp = [[INF] * n for _ in range(1 << m)]
    
    # Base cases: from school (0,0) to each mall
    for i in range(n):
        x, y, t = malls[i]
        mask = 1 << (t - 1)
        cost = 1 if abs(x) < abs(y) else 0
        dp[mask][i] = cost
    
    # Transitions
    for mask in range(1 << m):
        for i in range(n):
            if dp[mask][i] == INF: continue
            xi, yi, ti = malls[i]
            
            for j in range(n):
                if i == j: continue
                xj, yj, tj = malls[j]
                
                # Check if item type tj is already in mask
                t_bit = 1 << (tj - 1)
                if mask & t_bit: continue
                
                next_mask = mask | t_bit
                
                # Cost from i to j
                dist_x = abs(xj - xi)
                dist_y = abs(yj - yi)
                cost = 1 if dist_x < dist_y else 0
                
                if dp[next_mask][j] > dp[mask][i] + cost:
                    dp[next_mask][j] = dp[mask][i] + cost
                    
    # Final answer: return to school
    full_mask = (1 << m) - 1
    min_moves = INF
    for i in range(n):
        if dp[full_mask][i] == INF: continue
        x, y, _ = malls[i]
        cost_back = 1 if abs(x) < abs(y) else 0
        min_moves = min(min_moves, dp[full_mask][i] + cost_back)
        
    return min_moves if min_moves != INF else -1

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shopping_route(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases adapted for HDL constraints (n <= 8, m <= 8)
    # Input format: n, m, then n lines of x, y, type
    test_data = [
        {
            "n": 3, "m": 2,
            "malls": [(1, 1, 2), (1, 2, 1), (-1, 1, 2)],
            "expected": 0
        },
        {
            "n": 4, "m": 3,
            "malls": [(1, 2, 1), (-1, 2, 2), (-1, -2, 2), (-2, -4, 3)],
            "expected": 3
        },
        {
            "n": 1, "m": 1,
            "malls": [(5, 10, 1)],
            "expected": 2  # 1 (to mall) + 1 (back) = 2
        }
    ]
    
    for test_idx, data in enumerate(test_data):
        dut._log.info(f"Running Test Case {test_idx + 1}")
        
        n = data["n"]
        m = data["m"]
        malls = data["malls"]
        expected = data["expected"]
        
        if n > MAX_N or m > MAX_M:
            dut._log.warning(f"Skipping test case {test_idx+1}: n={n} or m={m} exceeds HDL limits ({MAX_N}, {MAX_M})")
            continue
            
        # Python Ref Check
        py_res = solve_python(malls, m)
        dut._log.info(f"Python ref result: {py_res}")
        
        # Load Inputs into DUT
        # Sequence: Start -> (N valid cycles) -> Monitor Result
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send Data
        for x, y, t in malls:
            await RisingEdge(dut.clk)
            dut.din_valid.value = 1
            dut.din_x.value = clamp_to_width(x, 16)
            dut.din_y.value = clamp_to_width(y, 16)
            dut.din_type.value = clamp_to_width(t, 4)
            
            # Wait for ready if handshake exists
            if has_signal(dut, 'din_ready'):
                while not (is_value_defined(dut.din_ready.value) and int(dut.din_ready.value) == 1):
                    await RisingEdge(dut.clk)
                    dut.din_valid.value = 0 # Deassert if ready high? Handshake usually keeps valid high
                    dut.din_valid.value = 1 # Keep high for burst
        
        dut.din_valid.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
        except TestFailure as e:
            dut._log.error(f"Test {test_idx+1} failed: {e}")
            raise
            
        # Read Result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {test_idx+1}: Result undefined")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {test_idx+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"Test {test_idx+1} Passed")
        
        # Reset for next test
        await reset_dut(dut)

    dut._log.info("All tests passed!")