import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def calculate_permutations(N, K):
    """Calculate permutations of N elements with order K (small values)"""
    from math import factorial
    from itertools import product
    
    # Generate all partitions of N (represented as list of cycle lengths)
    def partitions(n, max_val=None):
        if max_val is None:
            max_val = n
        if n == 0:
            yield []
            return
        for i in range(min(n, max_val), 0, -1):
            for p in partitions(n - i, i):
                yield [i] + p
    
    total = 0
    for part in partitions(N):
        # Calculate LCM of cycle lengths
        def gcd(a, b):
            while b:
                a, b = b, a % b
            return a
        
        def lcm(a, b):
            if a == 0 or b == 0:
                return 0
            return abs(a * b) // gcd(a, b)
        
        current_lcm = 1
        for length in part:
            current_lcm = lcm(current_lcm, length)
            if current_lcm > K:
                break
        
        if current_lcm != K:
            continue
        
        # Count cycles of each length
        from collections import Counter
        counts = Counter(part)
        
        # Calculate: N! / (prod(c^m * m!))
        numerator = factorial(N)
        denominator = 1
        for c, m in counts.items():
            denominator *= (c ** m) * factorial(m)
        
        total += numerator // denominator
    
    return total

@cocotb.test()
async def test_permutation_counter(dut):
    """Test permutation counter module"""
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.K.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled down)
    test_cases = [
        (3, 2, 3),   # From sample
        (4, 2, 6),   # New: 4 elements order 2
        (4, 4, 6),   # New: 4 elements order 4
        (5, 5, 24),  # New: 5 elements order 5
        (6, 6, 240), # From sample
    ]
    
    passed = 0
    total = len(test_cases)
    
    for N, K, expected in test_cases:
        # Start computation
        dut.N.value = N
        dut.K.value = K
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 1000 cycles)
        timeout = 1000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Timeout for N={N}, K={K}")
        
        # Check result
        result = int(dut.result.value)
        if result == expected:
            passed += 1
            dut._log.info(f"N={N}, K={K}: {result} == {expected} ✓")
        else:
            dut._log.error(f"N={N}, K={K}: {result} != {expected}")
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"