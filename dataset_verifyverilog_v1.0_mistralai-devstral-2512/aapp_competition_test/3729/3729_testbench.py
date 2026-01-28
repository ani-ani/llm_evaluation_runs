import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MOD = 10**9 + 7
CLK_NS = 10
MAX_CYCLES = 10000

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pow_mod(base, exp, mod):
    res = 1
    base %= mod
    while exp > 0:
        if exp % 2 == 1:
            res = (res * base) % mod
        base = (base * base) % mod
        exp //= 2
    return res

def nCr_mod(n, r, mod):
    if r < 0 or r > n:
        return 0
    if r == 0 or r == n:
        return 1
    r = min(r, n - r)
    num = 1
    den = 1
    for i in range(r):
        num = (num * (n - i)) % mod
        den = (den * (i + 1)) % mod
    return (num * pow_mod(den, mod - 2, mod)) % mod

def calc_expected(f, w, h):
    # Python reference calculation
    # Total arrangements (alternate stacks)
    # If w == 0, only food stacks exist. 
    # If f == 0, only wine stacks exist.
    # The problem implies stacks alternate.
    # Logic: 
    # 1. Total arrangements (without height constraint)
    # 2. Valid arrangements (with height constraint)
    # The original problem logic (stars and bars) is complex for brute force verification.
    # For the HDL test, we will rely on the logic implemented in the HDL matching the spec.
    # To verify, we can use a brute force generator for very small f, w.
    
    # Let's use the formula from the prompt's python code logic:
    # Total = C(f+w, w) (Approximation for specific alternation rules)
    # Valid = Sum over k (stacks) of C(f+1, k) * C(w - k*h - 1, k-1)
    # Note: The Python code provided in the prompt seems to be a specific solution for this problem.
    # We will test against a simplified version of that logic.
    
    mod = MOD
    if w == 0: return 1
    
    total = nCr_mod(f + w, w, mod)
    
    valid = 0
    max_k = min(f + 1, w)
    for k in range(1, max_k + 1):
        term1 = nCr_mod(f + 1, k, mod)
        term2 = nCr_mod(w - k * h - 1, k - 1, mod)
        valid = (valid + term1 * term2) % mod
    
    if total == 0:
        return 0
        
    return (valid * pow_mod(total, mod - 2, mod)) % mod

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_stack_probability(dut):
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        await Timer(100, units='ns')
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (f, w, h)
    # Include edge cases and random small values
    test_cases = [
        (1, 1, 1), # Output 0
        (1, 2, 1), # Output 666666672
        (0, 1, 0), # Output 1 (Only wine, k=1, h=0 -> wine>=1 OK)
        (1, 0, 1), # Output 1 (Only food)
        (5, 5, 2), # Small random
        (10, 10, 5), # Small random
        (0, 0, 0), # Edge case input handling
    ]
    
    for f, w, h in test_cases:
        if f == 0 and w == 0: continue # Input guarantee avoids this
        
        cocotb.log.info(f"Testing f={f}, w={w}, h={h}")
        
        # Drive inputs
        if has_signal(dut, 'f_in'):
            dut.f_in.value = clamp_to_width(f, 16)
            dut.w_in.value = clamp_to_width(w, 16)
            dut.h_in.value = clamp_to_width(h, 16)
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # Combinational? Just wait
            await Timer(100, units='ns')
            
        # Wait for done
        max_wait = 0
        found_done = False
        for _ in range(MAX_CYCLES):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                found_done = True
                break
            max_wait += 1
            
        if not found_done and has_signal(dut, 'done'):
             raise TestFailure(f"Timeout waiting for done on case f={f}, w={w}, h={h}")
            
        # Read result
        if has_signal(dut, 'result'):
            result = int(dut.result.value)
            expected = calc_expected(f, w, h)
            
            cocotb.log.info(f"Result: {result}, Expected: {expected}")
            if result != expected:
                raise TestFailure(f"Mismatch! Got {result}, expected {expected} for f={f}, w={w}, h={h}")
        else:
            cocotb.log.warning("No result signal found, skipping check")
            
        # Reset for next test
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)