import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_flow(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await Timer(20, units='ns')
    # Test case 1: Sample 1 (4 nodes)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.node_cnt.value = 4
    dut.edge_cnt.value = 4
    dut.src.value = 0
    dut.sink.value = 3
    edges = [
        (0, 1, 4, 10),
        (1, 2, 2, 10),
        (0, 2, 4, 30),
        (2, 3, 4, 10)
    ]
    # Load edges
    for (u, v, c, w) in edges:
        dut.u_in.value = u
        dut.v_in.value = v
        dut.c_in.value = c
        dut.w_in.value = w
        await RisingEdge(dut.clk)
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.max_flow.value == 4, "Test 1 flow failed"
    assert dut.min_cost.value == 140, "Test 1 cost failed"
    # Test case 2: Sample 2 (2 nodes)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.node_cnt.value = 2
    dut.edge_cnt.value = 1
    dut.src.value = 0
    dut.sink.value = 1
    # Load edge
    dut.u_in.value = 0
    dut.v_in.value = 1
    dut.c_in.value = 1000
    dut.w_in.value = 100
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.max_flow.value == 1000, "Test 2 flow failed"
    assert dut.min_cost.value == 100000, "Test 2 cost failed"
    # Test case 3: Reverse source/sink
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.node_cnt.value = 2
    dut.edge_cnt.value = 1
    dut.src.value = 1
    dut.sink.value = 0
    # Load edge (still 0->1)
    dut.u_in.value = 0
    dut.v_in.value = 1
    dut.c_in.value = 1000
    dut.w_in.value = 100
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.max_flow.value == 0, "Test 3 flow failed"
    assert dut.min_cost.value == 0, "Test 3 cost failed"
    dut._log.info("3/3 tests passed")