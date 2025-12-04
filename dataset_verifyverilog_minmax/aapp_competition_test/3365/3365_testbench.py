import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_max_partition(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        ([10,5,4,8,3,3,3,3], 3, 2),
        ([10,11,12,13,14,14,14,14], 3, 0),
        ([10,8,12,11,14,14,14,14], 3, 2)
    ]
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for vals, k_in, expected in test_cases:
        for i in range(8):
            getattr(dut, f"v{i}").value = vals[i]
        dut.k.value = k_in
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        if dut.score.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: For inputs k={k_in}, vals={vals}, expected {expected}, got {dut.score.value.value}")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")
