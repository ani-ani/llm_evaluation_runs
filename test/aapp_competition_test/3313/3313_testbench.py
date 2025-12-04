import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_gem_collector(dut):
    # Create 100MHz clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1 (from sample input, scaled)
    gems_x = [8, 5, 4, 4, 7, 0, 0, 0]
    gems_y = [8, 1, 6, 7, 9, 0, 0, 0]
    test_params = (
        (5, 1, 10, 10, gems_x, gems_y, 3),
        (5, 1, 100, 100, [27,79,40,62,52,0,0,0], [75,77,93,41,45,0,0,0], 3),
        (4, 1, 20, 20, [10,5,15,8,0,0,0,0], [5,10,15,20,0,0,0,0], 4)
    )

    passed = 0
    for (n, r, w, h, gx, gy, expected) in test_params:
        # Load inputs
        dut.gem_count.value = n
        dut.r.value = r
        dut.w.value = w
        dut.h.value = h
        for i in range(8):
            dut.gem_x[i].value = gx[i]
            dut.gem_y[i].value = gy[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.max_gems.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: Got {dut.max_gems.value}, expected {expected}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Tests passed: {passed}/{len(test_params)}")
    assert passed == len(test_params)
