import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

MOD = 1000000007

def python_fib(n):
    if n == 0: return 1
    if n == 1: return 1
    a, b = 1, 1
    for _ in range(2, n + 1):
        a, b = b, (a + b) % MOD
    return b

def python_solve(n, m):
    fn = python_fib(n)
    fm = python_fib(m)
    # Formula: 2 * (f[n] + f[m] - 1)
    res = (2 * (fn + fm - 1)) % MOD
    return res

@cocotb.test()
def test_random_picture(dut):
    """Test random picture counter for small N and M"""
    # Test cases: (N, M)
    test_cases = [
        (1, 1),
        (1, 2),
        (2, 1),
        (2, 3),
        (3, 3),
        (5, 5),
        (10, 10),
        (15, 15)
    ]

    passed = 0
    total = len(test_cases)

    for n, m in test_cases:
        # Set inputs
        dut.N.value = n
        dut.M.value = m
        
        # Wait for combinational logic to settle (small delay)
        await Timer(10, units='ns')
        
        # Get expected value
        expected = python_solve(n, m)
        
        # Get actual value from DUT
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
            dut._log.info(f"N={n}, M={m}: PASS (Result={actual})")
        else:
            dut._log.error(f"N={n}, M={m}: FAIL (Expected={expected}, Got={actual})")

    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
