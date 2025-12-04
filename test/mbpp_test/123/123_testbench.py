import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_amicable_sum(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        (99, 0),    # No amicable pairs
        (220, 504), # Sum of (220 + 284)
        (300, 504), # Same sum since 284 <= 300
        (999, 504), # Original test case 1
    ]

    passed = 0
    dut._log.info(f"Initializing")

    for (limit_val, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # Start computation
        dut.limit.value = limit_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if int(dut.sum.value) == expected:
            passed += 1
            dut._log.info(f"PASS: limit={limit_val} sum={dut.sum.value}")
        else:
            dut._log.error(f"FAIL: limit={limit_val} got {dut.sum.value}, expected {expected}")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)