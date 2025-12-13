import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time

@cocotb.test()
async def test_debate_selector(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1 (Original Example 1 - scaled)
    test1 = [
        (0b11, 6), (0b10, 4), (0b01, 3),
        (0b00, 3), (0b00, 7), (0b00, 9)
    ]
    for view, inf in test1:
        dut.view_in.value = view
        dut.influence_in.value = inf
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while dut.done.value != 1:
        await RisingEdge(dut.clk)
    assert dut.max_influence.value == 22, "Test1 failed: Expected 22, got %d" % dut.max_influence.value

    # Reset between tests
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 2 (Original Example 3)
    test2 = [
        (0b11,19), (0b10,22), (0b00,18),
        (0b00,29), (0b11,29), (0b10,28)
    ]
    for view, inf in test2:
        dut.view_in.value = view
        dut.influence_in.value = inf
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while dut.done.value != 1:
        await RisingEdge(dut.clk)
    assert dut.max_influence.value == 105, "Test2 failed: Expected 105, got %d" % dut.max_influence.value

    # Edge case: All '00'
    test3 = [(0b00,5000)] * 3
    for view, inf in test3:
        dut.view_in.value = view
        dut.influence_in.value = inf
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while dut.done.value != 1:
        await RisingEdge(dut.clk)
    assert dut.max_influence.value == 0, "Test3 failed: Expected 0, got %d" % dut.max_influence.value

    dut._log.info("3/3 tests passed")