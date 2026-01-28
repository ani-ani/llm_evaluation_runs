import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python implementation of the logic for verification
def python_max_ranks(N, K, a_list, b_list):
    # N is fixed to 16 in this problem spec, but we handle any input size <= 16
    nodes = len(a_list)
    if nodes == 0:
        return 0
    
    # Build adjacency matrix
    edges = [[False] * nodes for _ in range(nodes)]
    for i in range(nodes):
        for j in range(nodes):
            if i == j:
                continue
            # Check constraints: a_i + K < a_j OR b_i + K < b_j
            if (a_list[i] + K < a_list[j]) or (b_list[i] + K < b_list[j]):
                edges[i][j] = True
    
    # Longest path DP
    # Initialize dp to 1
    dp = [1] * nodes
    
    # Relax edges repeatedly (N times sufficient for longest path in N nodes)
    for _ in range(nodes):
        new_dp = list(dp)
        for u in range(nodes):
            for v in range(nodes):
                if edges[u][v]:
                    if dp[v] + 1 > new_dp[u]:
                        new_dp[u] = dp[v] + 1
        dp = new_dp
    
    return max(dp) if nodes > 0 else 0

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_max_ranks(dut):
    # Parameters
    DATA_WIDTH = 8
    N = 16
    CLK_NS = 10
    
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define Test Cases
    # We will test 4 specific cases provided in the prompt (scaled to N=16 by padding)
    # And 1 random case
    
    base_cases = [
        (2, 10, [1, 12], [1, 13], 2),
        (2, 10, [1, 5], [1, 12], 2),
        (2, 10, [1, 5], [1, 4], 2),
        (2, 10, [1, 5], [4, 1], 2),
        (2, 10, [1, 12], [13, 1], 1)
    ]
    
    test_cases = []
    for case in base_cases:
        n_case, k, a_in, b_in, expected = case
        # Pad to N=16 with zeros (should not affect constraints much if edges are loose)
        a_pad = a_in + [0] * (N - n_case)
        b_pad = b_in + [0] * (N - n_case)
        test_cases.append((k, a_pad, b_pad, expected))
    
    # Add random case
    random.seed(42)
    rand_a = [random.randint(0, 100) for _ in range(N)]
    rand_b = [random.randint(0, 100) for _ in range(N)]
    rand_k = random.randint(0, 20)
    # Compute expected for random case using python function
    rand_exp = python_max_ranks(N, rand_k, rand_a, rand_b)
    test_cases.append((rand_k, rand_a, rand_b, rand_exp))

    passed = 0
    failed = 0
    
    for i, (k_val, a_vals, b_vals, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: K={k_val}, Expected={expected}")
        
        try:
            # Write Inputs
            if has_signal(dut, 'k'):
                dut.k.value = k_val
            
            # Write arrays
            # Check for packed array or individual signals
            if has_signal(dut, 'a_0'):
                # Individual signals
                for idx in range(N):
                    getattr(dut, f'a_{idx}').value = clamp_to_width(a_vals[idx], DATA_WIDTH)
                    getattr(dut, f'b_{idx}').value = clamp_to_width(b_vals[idx], DATA_WIDTH)
            else:
                # Packed array or array object
                for idx in range(N):
                    dut.a[idx].value = clamp_to_width(a_vals[idx], DATA_WIDTH)
                    dut.b[idx].value = clamp_to_width(b_vals[idx], DATA_WIDTH)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=1000)
            
            # Read Result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
            # Wait a cycle to ensure done goes low
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
