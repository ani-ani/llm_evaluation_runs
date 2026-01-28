import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def model(a, s):
    n = len(s)
    total = n*(n+1)//2
    F = {}
    for i in range(n):
        t = 0
        for j in range(i, n):
            t += int(s[j])
            F[t] = F.get(t, 0) + 1
    if a == 0:
        z = F.get(0, 0)
        return 2 * z * total - z * z
    else:
        ans = 0
        for U in F:
            if U != 0 and a % U == 0:
                V = a // U
                if V in F:
                    ans += F[U] * F[V]
        return ans

@cocotb.test(timeout_time=10000, timeout_unit="ns")
async def test_problem_solver(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for _ in range(10):
        s = ''.join(str(random.randint(0,9)) for _ in range(16))
        a = random.randint(0, 20736)
        expected = model(a, s)
        
        s_int = 0
        for i,c in enumerate(s):
            s_int |= int(c) << (4*i)
        
        dut.a.value = a
        dut.s.value = s_int
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 500:
                raise TestFailure("Timeout")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Mismatch: got {result}, expected {expected}")
        
        dut._log.info(f"Passed: a={a}, result={result}")