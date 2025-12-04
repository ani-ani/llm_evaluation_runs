import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_count_primes(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (5, 2),
        (10,4),
        (100,25),
        (2, 0),
        (3, 1)
    ]
    
    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    
    for n_val, expected in test_cases:
        dut.n.value = n_val
        dut.start.value = 1
        await ClockCycles(dut.clk, 1)
        dut.start.value = 0
        
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: For n={n_val}, count={dut.count.value} (expected {expected})")
        else:
            dut._log.error(f"FAIL: For n={n_val}, got {dut.count.value} but expected {expected}")
        
        await ClockCycles(dut.clk, 2)  # Allow reset between tests
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")