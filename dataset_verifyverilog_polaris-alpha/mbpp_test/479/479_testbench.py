import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_first_digit(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        (123, 1),
        (456, 4),
        (12, 1),
        (9999, 9),   # Additional test case
        (5, 5)       # Single-digit test
        # (65535 would return 6)
    ]

    passed = 0
    for num_val, expected in test_cases:
        # Apply stimulus
        dut.start.value = 0
        dut.num.value = num_val
        await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {num_val} -> {dut.result.value}")
        else:
            dut._log.error(f"FAIL: {num_val} got {dut.result.value}, expected {expected}")
        
        # Reset done
        await RisingEdge(dut.clk)
        
    dut._log.info(f"RESULT: {passed}/{len(test_cases)} tests passed")
