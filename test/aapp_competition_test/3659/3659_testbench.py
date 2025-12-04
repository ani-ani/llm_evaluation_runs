import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_bookcase(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Generate test cases for 5 books
    test_cases = [
        ( [220,195,200,180,190], [29,20,9,30,15], 18000 ), // Original scaled
        ( [300,300,150,200,250], [30,30,5,10,15], 67200 ), // Max heights case
        ( [150,150,150,150,150], [30,30,30,30,30], 450*150=67500 ) // Uniform books
    ]
    
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    passed = 0
    for (heights, thicknesses, expected) in test_cases:
        # Setup inputs
        dut.start.value = 0
        dut.h0.value = heights[0]
        dut.h1.value = heights[1]
        dut.h2.value = heights[2]
        dut.h3.value = heights[3]
        dut.h4.value = heights[4]
        dut.t0.value = thicknesses[0]
        dut.t1.value = thicknesses[1]
        dut.t2.value = thicknesses[2]
        dut.t3.value = thicknesses[3]
        dut.t4.value = thicknesses[4]
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (250 cycles)
        for _ in range(300):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify output
        if dut.min_area.value == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: Expected {expected}, got {dut.min_area.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
