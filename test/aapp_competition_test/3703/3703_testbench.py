import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

def phi(n):
    if n < 2: return n
    res = n
    i = 2
    while i*i <= n:
        if n % i == 0:
            while n % i == 0:
                n //= i
            res -= res // i
        i += 1
    if n > 1:
        res -= res // n
    return res

@cocotb.test()
async def test_eurus(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (7, 1, 6),
        (10, 2, 4),
        (640, 15, 2),
        (641, 17, 2),
        (16, 3, 4)
    ]
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    passed = 0
    for n_val, k_val, expected in test_cases:
        dut.n.value = n_val
        dut.k.value = k_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        cycles = 0
        while not dut.done.value and cycles < 20:
            await RisingEdge(dut.clk)
            cycles += 1
        result = dut.result.value
        if result == expected:
            passed += 1
            dut._log.info(f"Test passed for n={n_val}, k={k_val} => {result}")
        else:
            dut._log.error(f"FAIL: n={n_val},k={k_val} got={result}, exp={expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)