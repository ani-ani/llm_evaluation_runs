import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import math

MOD = 997

def py_model(n, a, b, k, s_bits):
    s = [1 if (s_bits >> i) & 1 else -1 for i in range(k)]
    total = 0
    for i in range(n+1):
        sign = s[i % k]
        term = pow(a, n-i, MOD) * pow(b, i, MOD) * sign
        total = (total + term) % MOD
    return total % MOD

@cocotb.test()
async def test_alternating_sum(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Original examples scaled mod 997
        (2, 2, 3, 3, 0b101, 7),  # "+-+" -> bit[0]=1, bit[1]=0, bit[2]=1
        (4, 1, 5, 1, 0b0, 216), # "-" -> all 0s, sum=-(5^0+5^1+5^2+5^3+5^4) = -781 mod 997 = 216
        # Additional test cases
        (3, 2, 3, 2, 0b10, (8 - 12 + 27) % MOD),         # n=3, "-+"
        (0, 5, 5, 1, 0b1, 1),                             # n=0 case
    ]
    passed = 0
    for n, a, b, k, s_bits, expected in test_cases:
        # Apply test inputs
        dut.n.value = n
        dut.a.value = a % MOD
        dut.b.value = b % MOD
        dut.k.value = k
        dut.s.value = s_bits
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Check result
        result = dut.result.value.integer
        assert result == expected, "Failed: n={},{},{},{},{} | Result={}, Expected={}".format(n,a,b,k,s_bits,result,expected)
        passed += 1
    dut._log.info("{} / {} tests passed".format(passed, len(test_cases)))
