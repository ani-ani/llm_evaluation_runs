import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

MOD = 10**9 + 7

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

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Precompute for test cases
# Case 1: n=5, hints: [2,4 same], [3,5 same] -> components: 1,2-3-4-5 -> 2^2=4
# Case 2: conflicts -> 0

def solve_case(n, m, hints):
    MOD = 10**9 + 7
    parent = list(range(n))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra
    
    # Process same hints first
    same_hints = [(l-1, r-1) for l,r,t in hints if t == 'same']
    for l,r in same_hints:
        for i in range(l, r):
            union(i, i+1)
    
    # Check different hints
    diff_hints = [(l-1, r-1) for l,r,t in hints if t == 'different']
    for l,r in diff_hints:
        for i in range(l, r+1):
            for j in range(i+1, r+1):
                if find(i) == find(j):
                    return 0
    
    # Count components
    roots = set()
    for i in range(n):
        roots.add(find(i))
    return pow(2, len(roots), MOD)

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_true_false(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (5, 2, [(2,4,'same'), (3,5,'same')], 4),
        (5, 3, [(1,3,'same'), (2,5,'same'), (1,5,'different')], 0)
    ]
    
    for idx, (n, m, hints, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {idx+1}: n={n}, m={m}, expected={expected}")
        
        # Reset
        dut.n.value = n
        dut.m.value = m
        
        # Initialize all hint inputs to 0
        for i in range(32):
            getattr(dut, f'hint_l_{i}').value = 0
            getattr(dut, f'hint_r_{i}').value = 0
            getattr(dut, f'hint_type_{i}').value = 0
            getattr(dut, f'hint_valid_{i}').value = 0
        
        # Load hints
        for i, (l, r, typ) in enumerate(hints):
            getattr(dut, f'hint_l_{i}').value = l
            getattr(dut, f'hint_r_{i}').value = r
            type_val = 1 if typ == 'different' else 0
            getattr(dut, f'hint_type_{i}').value = type_val
            getattr(dut, f'hint_valid_{i}').value = 1
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Case {idx+1}: Expected {expected}, got {result}")
    
    cocotb.log.info("All tests passed")