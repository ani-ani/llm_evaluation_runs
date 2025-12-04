import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_fib4(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (0, 0),
        (1, 0),
        (2, 2),
        (3, 0),
        (5, 4),
        (6, 8),
        (7, 14),
        (8, 28),
        (10, 104),
        (12, 386)
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for (n_val, expected) in test_cases:
        cycles_needed = max(0, n_val - 3)
        
        dut.start.value = 1
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation to complete
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value.integer == expected:
            passed += 1
            dut._log.info(f"PASS: fib4({n_val}) = {dut.result.value}")
        else:
            dut._log.error(f"FAIL: fib4({n_val}) = {dut.result.value}, expected {expected}")
        
        # Allow 1 cycle idle between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{len(test_cases)} tests passed")