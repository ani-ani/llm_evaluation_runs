import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_sum_squares(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    test_cases = [
        (0, [], 0),
        (3, [1,2,3], 6),
        (3, [1,4,9], 14),
        (5, [-1,-5,2,-1,-5], -126),
        (1, [0], 0),
        (5, [-56,-99,1,0,-2], 3030)
    ]
    
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for (length, lst, expected) in test_cases:
        # Pad test vector to 8 elements
        padded_lst = lst + [0]*(8 - len(lst))
        
        # Assign inputs
        for i, val in enumerate(padded_lst):
            setattr(dut, f"lst_{i}", val)
        dut.length.value = length
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.sum.value.integer == expected:
            passed += 1
            dut._log.info(f"PASS: Length {length}, sum {dut.sum.value} == {expected}")
        else:
            dut._log.error(f"FAIL: Length {length}, got {dut.sum.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")