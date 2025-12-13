import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_lucky_numbers(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    test_cases = [
        (2, 45),  
        (3, 150)
    ]
    passed = 0
    
    for n_val, expected in test_cases:
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.supply_count.value == expected:
            passed += 1
            dut._log.info(f"Test passed for n={n_val}: got {dut.supply_count.value}")
        else:
            dut._log.error(f"Test FAILED for n={n_val}: expected {expected}, got {dut.supply_count.value}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
