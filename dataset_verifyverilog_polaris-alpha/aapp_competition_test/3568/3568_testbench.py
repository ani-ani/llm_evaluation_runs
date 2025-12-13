import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_floppy_scheduler(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Possible scenario (1 freq, 2 intervals)
    dut.f.value = 1
    dut.t_0.value = 6
    dut.n_0.value = 2
    for i in range(0, 2*2):  # Load 2 intervals (4 values)
        dut.intervals_0[i].value = [0,4,6,12][i]  # Corrected order
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (simplified wait)
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.possible.value == 1, "TC1: Should be possible but got impossible"
    
    # Test case 2: Impossible scenario (1 freq, 3 intervals)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.f.value = 1
    dut.t_0.value = 6
    dut.n_0.value = 3
    for i in range(0, 2*3):
        dut.intervals_0[i].value = [0,5,6,8,9,14][i]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.possible.value == 0, "TC2: Should be impossible but got possible"
    
    # Test case 3: Multi-frequency check (2 freqs, possible)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.f.value = 2
    # Freq 0
    dut.t_0.value = 6
    dut.n_0.value = 2
    for i in range(0, 4):
        dut.intervals_0[i].value = [0,4,6,12][i]
    # Freq 1
    dut.t_1.value = 8
    dut.n_1.value = 1
    for i in range(0, 2):
        dut.intervals_1[i].value = [2,10][i]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.possible.value == 1, "TC3: Multi-freq should be possible"
    
    dut._log.info("3/3 tests passed")