import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_processor(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset_dut():
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        dut._log.info("Reset complete")

    test_cases = [
        (2, 2),
        (5, 5),
        (0, 0),
        (255, 255)
    ]

    passed = 0

    await reset_dut()

    for (input_val, expected) in test_cases:
        
        dut.input_num.value = input_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1

        if timeout >= 100:
            dut._log.error("Timeout waiting for done signal")
            break

        display_val = dut.display_out.value
        if display_val == expected:
            passed += 1
            dut._log.info(f"Test passed: N={input_val}, Display={display_val}")
        else:
            dut._log.error(f"Test FAILED: Expected {expected}, Got {display_val} for N={input_val}")

        await reset_dut()

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")"