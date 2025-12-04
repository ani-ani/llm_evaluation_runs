import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def bell_number_test(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_vectors = [
        (0, 1),
        (1, 1),
        (2, 2),
        (3, 5),
        (4, 15),
        (5, 52)
    ]

    passed = 0
    for (n_val, expected) in test_vectors:
        # Apply inputs
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max wait based on n^2)
        max_wait = (n_val+1)*(n_val+1)*2 + 10
        for _ in range(max_wait):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Check result
        if dut.bell_out.value == expected:
            dut._log.info(f"PASS: n={n_val} → Bell={dut.bell_out.value}")
            passed += 1
        else:
            dut._log.error(f"FAIL n={n_val}: got {dut.bell_out.value}, expected {expected}")

    # Summary
    total = len(test_vectors)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"