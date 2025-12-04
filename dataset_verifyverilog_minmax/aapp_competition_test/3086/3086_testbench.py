import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time
from math import floor

@cocotb.test()
async def test_event_solver(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: Single valid event (5)
    dut.t0_start_day.value = 26
    dut.t0_start_month.value = 2
    dut.t0_end_day.value = 3
    dut.t0_end_month.value = 3
    dut.t0_freq0.value = 1
    dut.t0_freq1.value = 0
    dut.t0_freq2.value = 0
    # Set other telescopes to freq=0
    for t in [1,2]:
        setattr(dut, f't{t}_freq0', 0)
        setattr(dut, f't{t}_freq1', 0)
        setattr(dut, f't{t}_freq2', 0)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.solution_found.value == 1, "Test1: Solution not found"
    assert dut.d0.value == 5, "Test1: Expected d0=5"
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0  # Reset for next test
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 2: Single event (185)
    dut.t0_freq0.value = 2  # Update frequency
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.solution_found.value == 1, "Test2: Solution not found"
    assert dut.d0.value == 185, "Test2: Expected d0=185"
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 3: Multiple telescopes and events (102,204,125)
    # Telescope 0 data (22 03 01 10 9 10 10)
    dut.t0_start_day.value = 22
    dut.t0_start_month.value = 3
    dut.t0_end_day.value = 1
    dut.t0_end_month.value = 10
    dut.t0_freq0.value = 9
    dut.t0_freq1.value = 10
    dut.t0_freq2.value = 10
    # Telescope 1 (05 05 16 12 1 7 10)
    dut.t1_start_day.value = 5
    dut.t1_start_month.value = 5
    dut.t1_end_day.value = 16
    dut.t1_end_month.value = 12
    dut.t1_freq0.value = 1
    dut.t1_freq1.value = 7
    dut.t1_freq2.value = 10
    # Telescope 2 (20 06 15 01 4 9 10)
    dut.t2_start_day.value = 20
    dut.t2_start_month.value = 6
    dut.t2_end_day.value = 15
    dut.t2_end_month.value = 1  # Jan
    dut.t2_freq0.value = 4
    dut.t2_freq1.value = 9
    dut.t2_freq2.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.solution_found.value == 1, "Test3: Solution not found"
    assert dut.d0.value == 102 and dut.d1.value == 204 and dut.d2.value == 125, "Test3: Mismatch"
    dut._log.info("3/3 tests passed")