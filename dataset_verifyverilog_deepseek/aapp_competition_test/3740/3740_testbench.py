import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_digit_sum_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (1, 9),   # Original sample
        (2, 98),  # Original sample
        (10, 1744),
        (50, 921888),
        (100, 998092)
    ]
    
    passed = 0
    MOD = 10**9+7
    
    for s_val, expected in test_cases:
        # Reset and initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input and start
        dut.S_in.value = s_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        result = dut.count.value % MOD
        if result == expected % MOD:
            passed += 1
        else:
            dut._log.error(f"Failed S={s_val}: Got {result}, expected {expected%MOD}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
