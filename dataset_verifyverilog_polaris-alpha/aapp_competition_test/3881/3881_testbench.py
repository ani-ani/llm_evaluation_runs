import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

# Operation ROM initialization data (example first test case)
def init_ops():
    return {
        "ab": "a", "cc": "c", "ca": "a", "ee": "c", "ff": "d"
    }

@cocotb.test()
async def test_string_compressor(dut):
    test_cases = [
        (3, 5, 4),
        (2, 8, 1),
        (6, 2, 0),
        (3, 4, 2),
        (6, 1, 0)
    ]
    
    passed = 0
    
    # Clock generation
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    for (n, q, expected) in test_cases:
        dut._log.info(f"Testing n={n} q={q} expected={expected}")
        
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Manually reconfigure module for n (not synthesizable - use parameters in real code)
        # This assumes manual parameter change per test case in simulation
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"Test passed: got {dut.result.value}")
        else:
            dut._log.error(f"Test failed: got {dut.result.value}, expected {expected}")
        
        # Wait a few cycles before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
