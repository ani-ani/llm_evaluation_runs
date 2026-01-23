import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def is_prime(n):
    """Check if n is prime (Python reference)"""
    if n < 2:
        return False
    for i in range(2, int(n**0.5) + 1):
        if n % i == 0:
            return False
    return True

def largest_prime_factor_py(n):
    """Python reference implementation"""
    largest = 1
    # Check 2 separately
    if n % 2 == 0:
        largest = 2
        while n % 2 == 0:
            n //= 2
    # Check odd factors
    i = 3
    while i * i <= n:
        if n % i == 0:
            largest = i
            while n % i == 0:
                n //= i
        i += 2
    # If remaining n is greater than 1, it's prime
    if n > 1:
        largest = n
    return largest

@cocotb.test()
async def test_largest_prime_factor(dut):
    """Test largest_prime_factor module with various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from original problem
    test_cases = [
        (15, 5),
        (27, 3),
        (63, 7),
        (330, 11),
        (13195, 29),
    ]
    
    # Additional edge cases
    edge_cases = [
        (4, 2),      # 2^2
        (8, 2),      # 2^3
        (49, 7),     # 7^2
        (121, 11),   # 11^2
        (1024, 2),   # 2^10
        (143, 13),   # 11*13
        (2048, 2),   # From docstring example
    ]
    
    all_tests = test_cases + edge_cases
    passed = 0
    failed = 0
    
    for n, expected in all_tests:
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with timeout
        max_cycles = 300
        for i in range(max_cycles):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Test {n}: Timeout after {max_cycles} cycles")
        
        # Read result
        result = int(dut.result.value)
        
        if result == expected:
            print(f"PASS: n={n}, result={result}, expected={expected}")
            passed += 1
        else:
            print(f"FAIL: n={n}, result={result}, expected={expected}")
            failed += 1
    
    print(f"
=== Summary: {passed}/{len(all_tests)} tests passed ===")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")