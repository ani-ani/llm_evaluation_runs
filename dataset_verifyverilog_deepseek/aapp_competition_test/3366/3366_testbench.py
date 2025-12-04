import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_collatz(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (1, 1, 0),    // f(1)=0
        (2, 2, 1),    // f(2)=1
        (3, 3, 2),    // 3->4->2->1 = 2 steps
        (1, 3, 3),    // 0+1+2=3
        (74,74,11)    // Sample test case
    ]
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for L, R, expected in test_cases:
        dut.L.value = L
        dut.R.value = R
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done asserted
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        if dut.S.value == expected:
            passed += 1
            dut._log.info("Test passed: L=%d R=%d S=%d" % (L, R, dut.S.value))
        else:
            dut._log.error("Test failed: L=%d R=%d S=%d (expected %d)" % 
                          (L, R, dut.S.value.integer, expected))
        await RisingEdge(dut.clk)
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
    assert passed == len(test_cases)