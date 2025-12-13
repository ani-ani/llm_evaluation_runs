import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_highest_power(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (10, 8),
        (19, 16),
        (32, 32),
        (63, 32),   # Test maximum (2^5=32)
        (1, 1)      # Edge case (minimum)
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    for (n_val, expected) in test_cases:
        dut.start.value = 1
        dut.n_in.value = n_val
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        if int(dut.result.value) == expected:
            dut._log.info(f"PASS: n={n_val} => {int(dut.result.value)}")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n_val} => {int(dut.result.value)}, expected {expected}")
        
        await RisingEdge(dut.clk)
        if dut.done.value != 0:
            dut._log.error("FAIL: done not cleared after result")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")