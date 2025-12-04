import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

MOD = 1000000007

@cocotb.test()
async def test_path_counter(dut):
    
    # Generate clock (100MHz)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Test cases (scaled from original)
    test_cases = [
        (2, 1, 1, 2),  # Original sample
        (4, 1, 1, 20), # Example small case
        (3, 2, 1, 3)   # New test case
    ]
    
    await Timer(20, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for n, x, y, expected in test_cases:
        # Prepare inputs
        dut.N.value = n
        dut.X.value = x
        dut.Y.value = y
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: N={n}, X={x}, Y={y} => {dut.result.value} (expected {expected})")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)