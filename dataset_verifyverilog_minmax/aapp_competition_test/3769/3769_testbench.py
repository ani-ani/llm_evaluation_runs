import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

MOD = 10**9+7

# Helper for modular exponentiation (Python implementation)
def mod_exp(base, exp, mod):
    res = 1
    base %= mod
    while exp:
        if exp & 1:
            res = (res * base) % mod
        base = (base * base) % mod
        exp >>= 1
    return res

@cocotb.test()
async def test_function_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (p, k, expected)
    test_cases = [
        (3, 2, 3),   # Original sample 1
        (5, 4, 25),  # Original sample 2
        (5, 0, 5**4 % MOD),  # k=0 case: p^{p-1}
        (7, 1, 7**7 % MOD),  # k=1 case: p^p
        (11, 2, 11**5 % MOD)  # k=2 order 10 → (11-1)/10=1
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for p, k, expected in test_cases:
        dut.p.value = p
        dut.k.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 62 cycles)
        for _ in range(70):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        assert dut.done.value == 1, "Timeout"
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: p={p}, k={k} -> {dut.result.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
