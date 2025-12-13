import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_book_presentations(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [(0x0021, 2), (0x0003, 1), (0x8421, 4)]
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    passed = 0
    for (graph, expected) in test_cases:
        dut.bipartite_graph.value = graph
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        cycles = 0
        while not dut.done.value and cycles < 20:
            await RisingEdge(dut.clk)
            cycles += 1
        result = dut.max_matching.value
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: Input {hex(graph)} -> {result} (expected {expected})")
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
