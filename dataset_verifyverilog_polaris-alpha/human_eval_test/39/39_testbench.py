import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_prime_fib(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (1, 2),
        (2, 3),
        (3, 5),
        (4, 13),
        (5, 89),
        (6, 233),
        (7, 1597),
        (8, 28657)
    ]
    
    passed = 0
    dut._log.info(f"Testing prime Fibonacci sequence with {len(test_cases)} cases")
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i, (n_val, expected) in enumerate(test_cases):
        dut.start.value = 0
        dut.n.value = n_val
        
        # Wait 3 cycles between tests
        for _ in range(3):
            await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if int(dut.result.value) == expected:
            passed += 1
            dut._log.info(f"PASSED case {i+1}: prime_fib({n_val}) = {expected}")
        else:
            dut._log.error(f"FAILED case {i+1}: Got {int(dut.result.value)}, expected {expected}")
        
        # Add some spacing between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
TEST SUMMARY: {passed}/{len(test_cases)} cases passed")