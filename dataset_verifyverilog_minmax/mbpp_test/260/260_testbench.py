import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_nsw_prime(dut):
    # Test cases [n, expected]
    test_cases = [
        (0, 1),
        (1, 1),
        (3, 7),
        (4, 17),
        (5, 41)
    ]
    
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    passed = 0
    total = len(test_cases)
    
    # Initial reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for n_val, expected in test_cases:
        # Apply inputs
        dut.n_in.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        result = dut.result.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} result={result}")
        else:
            dut._log.error(f"FAIL: n={n_val} got {result}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(10, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")