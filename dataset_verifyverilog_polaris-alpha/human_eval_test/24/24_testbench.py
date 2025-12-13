import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_divisor(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (3, 1),
        (7, 1),
        (10, 5),
        (100, 50),
        (49, 7),
        (255, 85)  # Additional test case
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for n_val, expected in test_cases:
        dut.start.value = 0
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.divisor.value == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} divisor={dut.divisor.value}")
        else:
            dut._log.error(f"FAIL: n={n_val} got {dut.divisor.value}, expected {expected}")
        
        # Wait 1 cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)