import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_series_sum(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (n, expected_sum)
    test_cases = [
        (6, 12),
        (10, 30),
        (9, 25),
        (0, 0),   # Edge case
        (1, 1)    # Edge case
    ]
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await Timer(5, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for n_val, expected in test_cases:
        # Load input
        dut.n_in.value = n_val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
            
        # Check result
        if int(dut.sum.value) == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} sum={dut.sum.value} (expected {expected})")
        else:
            dut._log.error(f"FAIL: n={n_val} got {dut.sum.value}, expected {expected}")
        
        # Clear done (prep for next test)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")