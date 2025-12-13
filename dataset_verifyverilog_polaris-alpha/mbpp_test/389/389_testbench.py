import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_lucas(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (0, 2),   # L0
        (1, 1),   # L1
        (2, 3),   # L2 = 1+2
        (3, 4),   # L3 = 3+1
        (4, 7),   # L4 = 4+3
        (9, 76),  # L9
        (15, 1364) # L15 (max for 4-bit input)
    ]
    
    passed = 0
    dut._log.info("Starting tests...")
    
    for (n_val, expected) in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply input
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Verify
        if dut.result.value == expected:
            dut._log.info(f"PASS: L{n_val} = {dut.result.value}")
            passed += 1
        else:
            dut._log.error(f"FAIL: L{n_val} = {dut.result.value} (expected {expected})")
        
        # Reset between tests
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 1)
        dut.rst_n.value = 1
    
    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)