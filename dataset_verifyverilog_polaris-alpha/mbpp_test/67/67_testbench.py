import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_bell(dut):
    # Generate clock (100 MHz)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Test cases (n, expected)
    test_cases = [
        (0, 1),
        (2, 2),
        (4, 15),
        (6, 203),
        (8, 4140)
    ]
    
    passed = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    
    for n_val, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: B({n_val}) = {dut.result.value}")
        else:
            dut._log.error(f"FAIL: B({n_val}) = {dut.result.value}, expected {expected}")
        
        # Wait one cycle between tests
        await RisingEdge(dut.clk)
    
    # Wait a few cycles for visibility
    await Timer(20, units='ns')
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)