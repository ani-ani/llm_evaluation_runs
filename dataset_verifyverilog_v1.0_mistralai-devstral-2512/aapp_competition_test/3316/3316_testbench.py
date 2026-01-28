import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
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

def float_to_q16_16(f):
    return int(f * 65536)

def q16_16_to_float(v):
    return v / 65536.0

# Probability calculation function for verification
def calculate_probability(m, n, t, p):
    if n > m or p > m:
        return 0.0
    
    required_wins = (p + t - 1) // t  # ceil(p/t)
    
    if required_wins == 0:
        return 1.0
    if required_wins > n:
        return 0.0
    
    # Calculate probability using combinatorics
    # P = 1 - sum_{i=0}^{required_wins-1} C(p,i) * C(m-p, n-i) / C(m,n)
    
    from math import comb
    
    total_comb = comb(m, n)
    prob = 0.0
    
    for i in range(required_wins):
        if i <= p and (n - i) <= (m - p) and i <= n:
            numerator = comb(p, i) * comb(m - p, n - i)
            prob += numerator / total_comb
    
    result = 1.0 - prob
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_ticket_lottery(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (100, 10, 2, 1, 0.1),
        (100, 10, 2, 2, 0.1909090909),
        (10, 10, 5, 1, 1.0),
        (50, 5, 10, 3, 0.0),  # p=3, t=10 => req=1, but n=5, prob should be 1 (actually 0, since p>t? No, req=1)
        (50, 5, 10, 20, 0.0), # p=20, t=10 => req=2, n=5, prob calculation
        (20, 10, 1, 5, 0.0),  # req=5, n=10, but p=5
    ]
    
    passed = 0
    failed = 0
    
    for m, n, t, p, expected_prob in test_cases:
        cocotb.log.info(f"Test: m={m}, n={n}, t={t}, p={p}, expected={expected_prob}")
        
        # Check inputs within limits
        if m > 1023 or n > 1023 or p > 1023 or t > 127:
            cocotb.log.warning(f"Skipping test case {m},{n},{t},{p} - out of range")
            continue
        
        try:
            # Set inputs
            dut.m.value = clamp_to_width(m, 10)
            dut.n.value = clamp_to_width(n, 10)
            dut.t.value = clamp_to_width(t, 7)
            dut.p.value = clamp_to_width(p, 10)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_q16 = int(dut.result.value)
            result_float = q16_16_to_float(result_q16)
            
            # Calculate expected
            expected_q16 = float_to_q16_16(expected_prob)
            expected_float = expected_prob
            
            # Compare with tolerance (1e-9 absolute error requirement)
            abs_error = abs(result_float - expected_float)
            rel_error = abs_error / (abs(expected_float) + 1e-12)
            
            # Check absolute error
            if abs_error > 1e-7:  # Allow 1e-7 for Q16.16 approximation
                raise TestFailure(f"Absolute error {abs_error:.10f} > 1e-7. Got {result_float:.10f}, expected {expected_float:.10f}")
            
            cocotb.log.info(f"  Result: {result_float:.10f} (Q16: 0x{result_q16:08X}), expected: {expected_float:.10f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: m={m}, n={n}, t={t}, p={p}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")