import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import numpy as np

@cocotb.test()
async def test_max_executives(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())
    
    # Create reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (4, [1, 2, 1, 2, 0, 0, 0, 0], 3),  # Original sample input
        (6, [6, 4, 2, 2, 2, 2, 0, 0], 3),  # Original sample input
        (3, [5, 3, 4, 0, 0, 0, 0, 0], 2),  # Can split [5][3+4]
        (5, [10, 1, 1, 1, 1, 0, 0, 0], 1)   # Must give all to 1 executive
    ]
    
    passed = 0
    for (n, bananas, expected) in test_cases:
        # Load inputs while in IDLE state
        dut.N.value = n
        for i in range(8):
            dut.bananas[i].value = bananas[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (timeout after 40 cycles)
        for _ in range(40):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.k.value != expected:
            dut._log.error(f"Test failed: N={n}, bananas={bananas[:n]}
            Got: {dut.k.value}, Expected: {expected}")
        else:
            passed += 1
        
        # Reset before next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)