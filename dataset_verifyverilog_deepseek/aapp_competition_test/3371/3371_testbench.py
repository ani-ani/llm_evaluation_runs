import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_ncpc(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    # Test case 1: Impossible case (all pairs 1987)
    dut.start.value = 0
    dut.valid_pair.value = 1
    dut.n.value = 4
    pairs = [
        (1,2,1987), (2,3,1987), (1,3,1987),
        (2,4,1987), (1,4,1987), (3,4,1987)
    ]
    for (a,b,y) in pairs:
        dut.a.value = a
        dut.b.value = b
        dut.year.value = y - 1948  # Convert to 0-based
        await RisingEdge(dut.clk)
    dut.valid_pair.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait for processing
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.impossible.value == 1, "Test case 1 should be impossible"
    # Test case 2: Valid case (answer 1971)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.n.value = 6
    dut.valid_pair.value = 1
    pairs = [(1,2,1970), (3,4,1980), (5,6,1990)]
    for (a,b,y) in pairs:
        dut.a.value = a
        dut.b.value = b
        dut.year.value = y - 1948
        await RisingEdge(dut.clk)
    dut.valid_pair.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.Y.value + 1948 == 1971, f"Expected 1971 got {dut.Y.value + 1948}"
    dut._log.info("2/2 tests passed")