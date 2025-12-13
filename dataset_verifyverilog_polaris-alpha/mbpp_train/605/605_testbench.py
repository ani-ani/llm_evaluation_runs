import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import math

async def reset_dut(dut):
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_prime(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (0, 0), (1, 0), (2, 1), (3, 1), (4, 0),
        (13, 1), (7, 1), (251, 1), (255, 0)
    ]
    
    passed = 0
    await reset_dut(dut)
    
    for num, expected in test_cases:
        dut.start.value = 0
        dut.num.value = num
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.is_prime.value == expected:
            passed += 1
            dut._log.info(f"PASS: {num} => {dut.is_prime.value}")
        else:
            dut._log.error(f"FAIL: {num} => {dut.is_prime.value} (expected {expected})")
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info(f"
TEST SUMMARY: {passed}/{len(test_cases)} tests passed")