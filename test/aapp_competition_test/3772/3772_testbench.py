import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

async def reset_dut(dut):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

@cocotb.test()
async def test_resistance(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_vectors = [
        (1, 1, 1),
        (3, 2, 3),
        (5, 2, 4),
        (199, 200, 200),
        (21, 8, 7)
    ]
    
    await reset_dut(dut)
    passed = 0
    
    for (a_val, b_val, expected) in test_vectors:
        dut.start.value = 0
        dut.a.value = a_val
        dut.b.value = b_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: {a_val}/{b_val} - Got {dut.result.value}, Expected {expected}")
        
        await Timer(10, units='ns')
        
    dut._log.info(f"{passed}/{len(test_vectors)} tests passed")
    assert passed == len(test_vectors)