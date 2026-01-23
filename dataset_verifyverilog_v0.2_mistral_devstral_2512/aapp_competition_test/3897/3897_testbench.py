import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

MOD = 1000000007

def get_prime_factors_exponents(n):
    exponents = {}
    d = 2
    temp = n
    while d * d <= temp:
        while temp % d == 0:
            exponents[d] = exponents.get(d, 0) + 1
            temp //= d
        d += 1
    if temp > 1:
        exponents[temp] = exponents.get(temp, 0) + 1
    return exponents

def nCr_mod(n, r, mod):
    if r < 0 or r > n:
        return 0
    if r == 0 or r == n:
        return 1
    if r > n // 2:
        r = n - r
    num = 1
    den = 1
    for i in range(r):
        num = (num * (n - i)) % mod
        den = (den * (i + 1)) % mod
    return (num * pow(den, mod - 2, mod)) % mod

def calculate_expected(n_vals, a_vals):
    total_exponents = {}
    for x in a_vals:
        facs = get_prime_factors_exponents(x)
        for p, exp in facs.items():
            # Filter primes > 255 for the simplified problem
            if p <= 255:
                total_exponents[p] = total_exponents.get(p, 0) + exp
    
    ans = 1
    p = n_vals
    for exp in total_exponents.values():
        # C(k + p - 1, p - 1)
        comb = nCr_mod(exp + p - 1, p - 1, MOD)
        ans = (ans * comb) % MOD
    return ans

@cocotb.test()
async def test_decomposition(dut):
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.n_in.value = 0
    dut.valid_in.value = 0
    dut.last_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases from problem description (scaled down to fit constraints)
    # The prompt scales n to <= 4. 
    # Test Case 1: n=1, [15] -> 1. 15 fits in 16 bits.
    # Test Case 2: n=3, [1, 1, 2] -> 3. Fits constraints.
    # Test Case 3: n=2, [5, 7] -> 4. Fits constraints.
    
    test_cases = [
        (1, [15]),
        (3, [1, 1, 2]),
        (2, [5, 7]),
        (2, [4, 4]), # Exponents: 2^4. k=4, p=2. C(5,1)=5.
    ]

    for n, vals in test_cases:
        dut._log.info(f"Testing n={n}, values={vals}")
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Load inputs
        dut.n_in.value = n
        for i, val in enumerate(vals):
            dut.data_in.value = val
            dut.valid_in.value = 1
            dut.last_in.value = 1 if (i == len(vals) - 1) else 0
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        dut.last_in.value = 0
        
        # Wait for computation
        # Timeout mechanism
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 1000:
            raise TestFailure(f"Timeout for n={n}, vals={vals}")
            
        # Check result
        expected = calculate_expected(n, vals)
        actual = int(dut.result.value)
        
        if actual != expected:
            raise TestFailure(f"Mismatch: n={n}, vals={vals}. Expected {expected}, got {actual}")
        
        # Wait a bit before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    dut._log.info("All tests passed!")
