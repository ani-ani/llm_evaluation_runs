import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_divisor_sum(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        (8, 7),   # 1+2+4
        (12, 16), # 1+2+3+4+6
        (7, 1),   # only 1
        (1, 0),   # edge case (no divisors)
        (255, 177) # 1+3+5+15+17+51+85
    ]

    passed = 0
    for num_val, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Start computation
        dut.num.value = num_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check result
        if int(dut.sum.value) == expected:
            passed += 1
            dut._log.info(f"PASS: {num_val} => {expected}")
        else:
            dut._log.error(f"FAIL: {num_val} => {dut.sum.value}, expected {expected}")

        # Wait one cycle between tests
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)