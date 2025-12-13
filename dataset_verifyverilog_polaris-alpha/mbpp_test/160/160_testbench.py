import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_diophantine(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await Timer(5, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # (a, b, n, x, y, has_solution)
        (2, 3, 7, 2, 1, True),
        (4, 2, 7, 0, 0, False),
        (1, 13, 17, 4, 1, True),
        # Edge cases
        (5, 5, 5, 1, 0, True),   # 5*1 + 5*0 = 5
        (255, 1, 255, 1, 0, True),  # Max input
        (3, 5, 4, 3, -1, False)   # No solution existing
    ]

    passed = 0
    for test in test_cases:
        a_val, b_val, n_val, exp_x, exp_y, has_sol = test

        # Apply inputs
        dut.a.value = a_val
        dut.b.value = b_val
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check outputs
        if has_sol:
            if int(dut.x.value) == exp_x and int(dut.y.value) == exp_y:
                passed += 1
                dut._log.info(f"PASS: {a_val}*{dut.x.value} + {b_val}*{dut.y.value} = {n_val}")
            else:
                dut._log.error(f"FAIL: Got (x:{dut.x.value}, y:{dut.y.value}) Expected ({exp_x}, {exp_y})")
        else:
            if dut.no_sol.value:
                passed += 1
                dut._log.info(f"PASS: Correctly found no solution for ({a_val},{b_val},{n_val})")
            else:
                dut._log.error(f"FAIL: Expected no solution but got ({dut.x.value}, {dut.y.value})")
        await RisingEdge(dut.clk)  # Wait for done to clear

    # Print summary
    total = len(test_cases)
    dut._log.info(f"Test Results: {passed}/{total} tests passed")
    if passed < total:
        raise cocotb.result.TestFailure(f"Failed {total-passed} tests")
