import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
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

# --- Logic Helper ---
def count_distinct_prime_factors(n):
    if n <= 1: return 0
    primes = [2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97]
    count = 0
    for p in primes:
        if p*p > n: break
        if n % p == 0:
            count += 1
            while n % p == 0:
                n //= p
    if n > 1: count += 1
    return count

def compute_expected(N, S):
    n = N
    dp = [-1] * (1 << n)
    dp[0] = 0
    # Precompute revenue for all masks
    revenue = [0] * (1 << n)
    for mask in range(1, 1 << n):
        s_val = 0
        for i in range(n):
            if (mask >> i) & 1:
                s_val += S[i]
        revenue[mask] = count_distinct_prime_factors(s_val)
    
    for mask in range(1, 1 << n):
        sub = mask
        while sub > 0:
            # Don't transition from 0 if we want to fill everything
            # Actually, we iterate all non-empty proper subsets
            rest = mask ^ sub
            if dp[rest] != -1:
                if dp[mask] < dp[rest] + revenue[sub]:
                    dp[mask] = dp[rest] + revenue[sub]
            sub = (sub - 1) & mask
    return dp[(1<<n)-1]

# --- Testbench ---
DATA_WIDTH = 8
ARRAY_SIZE = 14
CLK_NS = 10
MAX_CYCLES = 30000

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
    # Reset
    if is_seq:
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    test_cases = [
        (1, [1]),
        (3, [4, 7, 8]),
        (5, [2, 3, 4, 5, 8]),
        (10, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    ]

    passed = 0
    failed = 0

    for N, S_vals in test_cases:
        exp = compute_expected(N, S_vals)
        cocotb.log.info(f"Test N={N}, S={S_vals}, Expected={exp}")
        
        try:
            # Set N
            if has_signal(dut, 'N'):
                dut.N.value = N
            
            # Set S array
            if has_signal(dut, 'S'):
                # Assuming dut.S is an array of signals
                for i in range(ARRAY_SIZE):
                    if i < N:
                        dut.S[i].value = S_vals[i]
                    else:
                        dut.S[i].value = 0
            
            # Start
            if is_seq and has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                found_done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        found_done = True
                        break
                
                if not found_done:
                    raise TestFailure(f"Timeout waiting for done signal")
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                res = int(dut.result.value)
                if res != exp:
                    raise TestFailure(f"Expected {exp}, got {res}")
                
                passed += 1
            else:
                # Combinational logic - just wait a bit
                await Timer(1000, units='ns')
                if has_signal(dut, 'result'):
                    res = int(dut.result.value)
                    if res != exp:
                        raise TestFailure(f"Expected {exp}, got {res}")
                passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
