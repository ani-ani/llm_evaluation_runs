import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_jacobsthal(dut):
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Test cases: (n, expected)
    test_cases = [
        (0, 0),  # base case
        (1, 1),  # base case
        (2, 1),
        (4, 5),
        (5, 11),
        (13, 2731)
    ]
    
    passed = 0
    
    # Initialize and reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for n, expected in test_cases:
        # Apply input
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            dut._log.info(f"PASS: n={n} → {expected}")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n} → {int(dut.result.value)} (expected {expected})")
        
        # Wait 1 cycle between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)