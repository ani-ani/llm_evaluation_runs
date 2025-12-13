import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_fluttershy(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Check results
    test_results = [
        (dut.max_customers.value, 3),
    ]
    
    passed = 0
    for actual, expected in test_results:
        if int(actual) == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_results)} tests passed")
    assert passed == len(test_results)