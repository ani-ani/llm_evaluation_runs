import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_fog_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    # Scaled test case 1 (adapted from sample input 1)
    dut.num_origins.value = 2
    # Fog 0: m=2, d=3, l=0, r=2, h=9, d_d=2, d_x=3, d_h=0
    dut.m_i[0].value = 2
    dut.d_i[0].value = 3
    dut.l_i[0].value = 0
    dut.r_i[0].value = 2
    dut.h_i[0].value = 9
    dut.delta_d_i[0].value = 2
    dut.delta_x_i[0].value = 3
    dut.delta_h_i[0].value = 0
    # Fog 1: m=1, d=6, l=1, r=4, h=6, d_d=3, d_x=-1, d_h=-2
    dut.m_i[1].value = 1
    dut.d_i[1].value = 6
    dut.l_i[1].value = 1
    dut.r_i[1].value = 4
    dut.h_i[1].value = 6
    dut.delta_d_i[1].value = 3
    dut.delta_x_i[1].value = -1
    dut.delta_h_i[1].value = -2
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for completion
    await cocotb.triggers.First(dut.done.value == 1, Timer(1000, "ns"))
    assert dut.missed_count.value == 3, "Test 1 failed: Expected 3, got %d" % dut.missed_count.value
    # Add more test cases here with similar structure
    dut._log.info("1/1 tests passed")