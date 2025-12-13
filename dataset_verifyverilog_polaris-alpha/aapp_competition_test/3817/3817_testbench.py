import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_non_wool_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (3, 2, 6),
        (1, 2, 3),
        (3, 1, 0),
        (4, 2, 0),
        (2, 2, 6)
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for (n_val, m_val, expected) in test_cases:
        dut.start.value = 0
        dut.n.value = n_val
        dut.m.value = m_val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
        result = dut.result.value.integer
        if result % 1000000009 == expected % 1000000009:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d m=%d got=%d expected=%d" % (n_val, m_val, result, expected))
        await RisingEdge(dut.clk)
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
    assert passed == len(test_cases)