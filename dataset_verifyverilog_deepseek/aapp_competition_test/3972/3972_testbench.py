import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_sequence_counter(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    test_cases = [
        (1, 1),
        (2, 4),
        (3, 15),
        (4, 58),
        (5, 166)
    ]
    passed = 0
    dut._log.info("Starting tests")
    for data in test_cases:
        n_val, expected = data
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        # Apply inputs
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for computation
        for _ in range(8):
            await RisingEdge(dut.clk)
        # Verify output
        if dut.done.value == 1 and dut.result.value == expected:
            passed += 1
            dut._log.info(f"Test passed: n={n_val} got {dut.result.value}")
        else:
            dut._log.error(f"Test failed: n={n_val} got {dut.result.value}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"