import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

MOD = 16777213  # Large prime < 2^24

def python_model(n, a, b, k, s_str):
    """Python reference for the adapted problem (24-bit modulus)"""
    # Map '++-' to [1, 1, -1]
    s = [1 if c == '+' else -1 for c in s_str]
    
    # Modular exponentiation
    def mod_pow(base, exp, mod):
        res = 1
        base %= mod
        while exp > 0:
            if exp & 1:
                res = (res * base) % mod
            base = (base * base) % mod
            exp >>= 1
        return res

    # Modular inverse
    def mod_inv(x, mod):
        # Fermat's little theorem for prime mod
        return mod_pow(x, mod - 2, mod)

    if a == 0:
        return 0 # Handle edge case

    inv_a = mod_inv(a, MOD)
    b_inv_a = (b * inv_a) % MOD
    
    # q = (b/a)^k
    q = mod_pow(b_inv_a, k, MOD)
    
    # T = (n + 1) // k
    T = (n + 1) // k
    
    # SumPeriod = sum_{i=0}^{k-1} s[i] * a^n * (b/a)^i
    # Let's factor out a^n: a^n * sum(s[i] * (b/a)^i)
    a_n = mod_pow(a, n, MOD)
    
    sum_inner = 0
    curr_ratio_pow = 1
    for i in range(k):
        term = s[i] * curr_ratio_pow
        sum_inner = (sum_inner + term) % MOD
        curr_ratio_pow = (curr_ratio_pow * b_inv_a) % MOD
    
    # Scale by a^n
    sum_period = (a_n * sum_inner) % MOD
    
    if q == 1:
        result = (sum_period * T) % MOD
    else:
        # Geometric series: sum_period * (q^T - 1) * inv(q - 1)
        q_t = mod_pow(q, T, MOD)
        num = (q_t - 1) % MOD
        den_inv = mod_inv((q - 1) % MOD, MOD)
        result = (sum_period * num) % MOD
        result = (result * den_inv) % MOD
    
    return result % MOD

@cocotb.test()
async def test_periodic_sum(dut):
    """Test the periodic_sum module"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.a.value = 0
    dut.b.value = 0
    dut.k.value = 0
    dut.s.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (2, 2, 3, 3, "+-+"),  # Scaled down from problem
        (4, 1, 5, 1, "-"),
        (1, 1, 4, 2, "-+"),
        (3, 1, 4, 4, "+--+"),
        (0, 5, 1, 6, "++---+"), # Edge case n=0
    ]
    
    for n, a, b, k, s_str in test_cases:
        # Calculate expected
        expected = python_model(n, a, b, k, s_str)
        
        # Drive inputs
        dut.n.value = n
        dut.a.value = a
        dut.b.value = b
        dut.k.value = k - 1  # Adjust for 0-indexed verilog logic if needed, or pass as is
        
        # Encode s string into bits (4 bits for max k=4)
        # s[0] is LSB
        s_val = 0
        for i, char in enumerate(s_str):
            if char == '+':
                s_val |= (1 << i)
        dut.s.value = s_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 500:
                raise TestFailure(f"Timeout waiting for done for inputs n={n}, a={a}, b={b}, k={k}")
        
        # Check result
        actual = int(dut.result.value)
        
        # Adjust for Python model negative results (keep positive modulo)
        if expected < 0:
            expected += MOD
            
        print(f"Test n={n}, a={a}, b={b}, k={k}, s={s_str}: Expected={expected}, Actual={actual}")
        
        if actual != expected:
            raise TestFailure(f"Mismatch! Expected {expected}, got {actual}")

    print("All tests passed!")
