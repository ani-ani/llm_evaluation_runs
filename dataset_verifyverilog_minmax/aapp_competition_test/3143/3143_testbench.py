import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_attendance(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (scaled inputs)
    test_cases = [
        # Format: (m, n, a[8], b[8], expected_k)
        (1, 1, [1,0,0,0,0,0,0,0], [1,0,0,0,0,0,0,0], 1),
        (5, 4, [4,1,2,4,4,0,0,0], [4,3,2,1,0,0,0,0], 7),
        (2, 2, [1,2,0,0,0,0,0,0], [2,1,0,0,0,0,0,0], 3)
    ]

    passed = 0
    for tcid, (m_val, n_val, a_vals, b_vals, exp_k) in enumerate(test_cases):
        # Apply inputs
        dut.m.value = m_val
        dut.n.value = n_val
        for i in range(8):
            dut.a[i].value = a_vals[i]
            dut.b[i].value = b_vals[i]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Wait for completion
        timeout = 1000
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1

        assert timeout > 0, "Test timed out"

        # Check result
        if dut.k.value == exp_k:
            passed += 1
            dut._log.info(f"Test {tcid} PASSED")
        else:
            dut._log.error(f"Test {tcid} FAILED: Got {dut.k.value}, expected {exp_k}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
