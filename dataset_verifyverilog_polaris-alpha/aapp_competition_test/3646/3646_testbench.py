import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_frog_jump(dut):
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset and initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (7, [2, 1, 0, 1, 2, 3, 3] + [0]*9, 5),
        (11, [7, 6, 1, 4, 1, 2, 1, 4, 1, 4, 5] + [0]*5, 10)
    ]
    
    passed = 0
    for n, spots, expected in test_cases:
        # Load inputs
        dut.N.value = n
        for i in range(16):
            dut.spots[i].value = spots[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.max_distance.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: N={n}, got {dut.max_distance.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")"