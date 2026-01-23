import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper to convert to Q16.16
def to_q16_16(value):
    return int(value * 65536)

# Helper to convert from Q16.16
def from_q16_16(value):
    return value / 65536.0

# Combinatorial helper for C(n,k)
def comb(n, k):
    if k > n or k < 0:
        return 0
    if k == 0 or k == n:
        return 1
    if k > n - k:
        k = n - k
    result = 1
    for i in range(k):
        result = result * (n - i) // (i + 1)
    return result

# Calculate exact probability
def exact_probability(m, n, t, p):
    k_min = (p + t - 1) // t  # ceil(p/t)
    k_max = min(p, n)
    if k_min > k_max:
        return 0.0
    
    numerator = 0
    for k in range(k_min, k_max + 1):
        numerator += comb(p, k) * comb(m - p, n - k)
    
    denominator = comb(m, n)
    if denominator == 0:
        return 0.0
    return numerator / denominator

@cocotb.test()
async def test_lottery_probability(dut):
    """Test lottery probability calculator"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.m.value = 0
    dut.n.value = 0
    dut.t.value = 0
    dut.p.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (100, 10, 2, 1),  # 0.1
        (100, 10, 2, 2),  # 0.1909090909
        (10, 10, 5, 1),   # 1.0
    ]
    
    passed = 0
    total = len(test_cases)
    
    for m, n, t, p in test_cases:
        # Skip if out of our scaled range
        if m > 255 or n > 32:
            print(f"Skipping test case m={m}, n={n}, t={t}, p={p} (out of range)")
            continue
            
        # Expected result
        expected = exact_probability(m, n, t, p)
        expected_q = to_q16_16(expected)
        
        # Send inputs
        dut.m.value = m
        dut.n.value = n
        dut.t.value = t
        dut.p.value = p
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 256 cycles)
        timeout = 300
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Timeout for case m={m}, n={n}, t={t}, p={p}")
        
        # Read result
        result_q = int(dut.result.value)
        result = from_q16_16(result_q)
        
        # Allow absolute error of 1e-9
        error = abs(result - expected)
        
        print(f"Case m={m}, n={n}, t={t}, p={p}")
        print(f"  Expected: {expected:.10f} (Q:{expected_q})")
        print(f"  Got:      {result:.10f} (Q:{result_q})")
        print(f"  Error:    {error:.12f}")
        
        if error <= 1e-9:
            passed += 1
            print("  PASS")
        else:
            print("  FAIL")
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
