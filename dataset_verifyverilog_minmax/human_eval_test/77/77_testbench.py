import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_cube(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await Timer(10, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    test_cases = [
        (1, True), 
        (2, False),
        (-1, True),
        (64, True),
        (180, False),
        (1000, True),
        (0, True),
        (1729, False)
    ]
    
    passed = 0
    await reset()
    
    for a_val, expected in test_cases:
        dut.a.value = a_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        result = bool(dut.is_cube.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {a_val} -> {expected}")
        else:
            dut._log.error(f"FAIL: {a_val} -> got {result}, expected {expected}")
        
        # Reset between tests
        await reset()
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")