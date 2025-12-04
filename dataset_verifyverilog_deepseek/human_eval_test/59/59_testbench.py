import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_prime_factor(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_vectors = [
        (15, 5),
        (27, 3),
        (63, 7),
        (330, 11),
        (13195, 29),
        (4096, 2)  # Additional edge case
    ]

    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    total = len(test_vectors)

    for input_val, expected in test_vectors:
        dut.start.value = 1
        dut.n.value = input_val
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion with timeout
        timeout = 1000
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout -= 1
            if timeout == 0:
                assert False, f"Timeout for input {input_val}"

        if int(dut.result.value) == expected:
            dut._log.info(f"PASS: n={input_val} result={dut.result.value}")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={input_val} got {dut.result.value}, expected {expected}")

        await RisingEdge(dut.clk)  # Wait one cycle between tests

    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total