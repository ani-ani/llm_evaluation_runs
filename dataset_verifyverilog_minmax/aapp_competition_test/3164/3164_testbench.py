import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_subarray(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled inputs)
    test_cases = [
        ([1, 2, 3, 3, 4, 2, 0, 0], 2),  # Original sampled case (pad zeros)
        ([1, 2, 1, 3, 1, 3, 1, 2], 4),  # Original test case 2
        ([1, 10, 1, 10, 1, 10, 1, 10], 0),  # All appear 4x → invalid
        ([5, 5, 5, 5, 5, 5, 5, 5], 0),  # All same, too frequent
        ([1,1,2,2,3,3,4,4], 8)  # Perfect case (all appear exactly twice)
    ]
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for arr, expected in test_cases:
        # Load array (simulate parallel load)
        for i, val in enumerate(arr):
            dut.arr[i].value = val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (15 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.max_length.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: arr=%s, got %d, expected %d" % (str(arr), int(dut.max_length.value), expected))
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")