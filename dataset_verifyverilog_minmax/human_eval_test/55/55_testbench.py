import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_fibonacci(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (original adapted + edge cases)
    test_cases = [
        (1, 1),
        (8, 21),
        (10, 55),
        (11, 89),
        (12, 144),
        (0, 0)  # Added edge case
    ]
    
    passed = 0
    for n_val, expected in test_cases:
        # Apply inputs
        dut.start.value = 0
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation
        cycles = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Verify result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: Fib({n_val}) = {dut.result.value}")
        else:
            dut._log.error(f"FAIL: Fib({n_val}) = {dut.result.value}, expected {expected}")
        
        # Reset (optional between tests)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")