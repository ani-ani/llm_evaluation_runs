import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_sds(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    test_cases = [
        (1, 5, 4),
        (1, 12, 4),
        (5, 1, 2),
        (1, 255, 16),  // max step test (won't find m)
        (100, 100, 1)  // direct match in step1
    ]
    passed = 0

    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    for r_val, m_val, expected_n in test_cases:
        dut.start.value = 0
        dut.r.value = r_val
        dut.m.value = m_val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        while not dut.done.value:
            await RisingEdge(dut.clk)

        if dut.n.value == expected_n:
            passed += 1
        else:
            dut._log.error(f"Failed: r={r_val}, m={m_val} => n={dut.n.value} (expected {expected_n})")
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")