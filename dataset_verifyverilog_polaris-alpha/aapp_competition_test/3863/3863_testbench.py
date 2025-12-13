import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

MOD = 10**9+7

async def reset(dut):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_palindrome_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (4, 2, 6),
        (1, 10, 10),
        (6, 3, 3**3 % MOD) # Simplified expected value
    ]
    
    await reset(dut)
    
    passed = 0
    for (n, k, expected) in test_cases:
        dut.N.value = n
        dut.K.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (timeout after 100 cycles)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Timeout waiting for done"
        
        result = dut.result.value.integer % MOD # Apply mod in case of overflow in test
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: N={n}, K={k} -> {{result}}, expected {{expected}}")
        
        await RisingEdge(dut.clk)
        dut.N.value = 0
        dut.K.value = 0
    
    dut._log.info(f"{{passed}}/{{len(test_cases)}} tests passed")