import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_perrin_sum(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        (0, 3),
        (1, 3),
        (2, 5),
        (9, 49),
        (10, 66),
        (11, 88),
        (15, 389)  # Added extended test case
    ]

    passed = 0
    dut.start.value = 0

    for n_val, expected in test_cases:
        # Reset module
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Apply inputs
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if int(dut.sum.value) == expected:
            dut._log.info(f"PASS: n={n_val} => sum={expected}")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n_val} => sum={int(dut.sum.value)} (expected {expected})")
        
        # Allow 1 cycle between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")