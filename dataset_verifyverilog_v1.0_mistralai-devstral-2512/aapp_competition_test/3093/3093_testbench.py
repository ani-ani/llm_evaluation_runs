import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Modulo constant
MOD = 1000000007

# Helpers
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
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference implementation
def solve_python(N, K, f_input):
    f = [x - 1 for x in f_input]  # Convert to 0-indexed
    visited = [False] * N
    total_ways = 1
    
    for i in range(N):
        if visited[i]:
            continue
        
        # Find component starting from i
        path = []
        curr = i
        while not visited[curr]:
            visited[curr] = True
            path.append(curr)
            target = f[curr]
            # If self-loop or already visited, stop
            if target == curr or visited[target]:
                break
            curr = target
        
        # Detect cycle
        cycle_start_idx = -1
        if f[curr] != curr: # Not a self-loop root
            try:
                cycle_start_idx = path.index(f[curr])
            except ValueError:
                cycle_start_idx = -1
        else:
            # Self loop at curr
            cycle_start_idx = len(path) - 1

        if cycle_start_idx != -1:
            cycle_len = len(path) - cycle_start_idx
            # Color cycle: K * (K-1)^(cycle_len - 1)
            if K == 1 and cycle_len > 1:
                return 0
            ways = K * pow(K - 1, cycle_len - 1, MOD)
        else:
            # No cycle in this component (tree only) or already processed tail
            ways = 1
            
        total_ways = (total_ways * ways) % MOD
        
    return total_ways

# Test cases
test_cases = [
    # (N, K, f_list, expected)
    (2, 3, [2, 1], 6),
    (3, 4, [2, 3, 1], 24),
    (3, 4, [2, 1, 1], 36),
    (1, 5, [1], 5),           # Self loop
    (2, 1, [1, 2], 2),        # Two self loops, K=1
    (2, 1, [2, 1], 0),        # 2-cycle, K=1
]

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_coloring(dut):
    # Setup
    clk = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clk.start())
    await reset_dut(dut)
    
    for i, (N, K, f_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: N={N}, K={K}, f={f_list}")
        
        # Set inputs
        dut.N.value = N
        dut.K.value = K
        
        # Write f_arr (array of 16 entries)
        # If single ported array: dut.f_arr[i].value
        # If packed: dut.f_arr.value = packed_val
        # We use the explicit index access as per guidelines
        for idx in range(16):
            val = 0
            if idx < N:
                val = f_list[idx]
            # Handle potential array naming variations
            if has_signal(dut, f'f_arr_{idx}'):
                getattr(dut, f'f_arr_{idx}').value = val
            elif has_signal(dut, 'f_arr'):
                dut.f_arr[idx].value = val
            else:
                raise TestFailure("f_arr signals not found")
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1} failed: Expected {expected}, got {result}")
        
        # Reset for next test
        await reset_dut(dut)
