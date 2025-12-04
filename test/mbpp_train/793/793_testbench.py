import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_last_position(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # (array, target, expected_index, expected_found)
        ([1,2,3,0,0,0,0,0], 1, 0, True),    # Test 1 (padded with zeros)
        ([1,1,1,2,3,4,0,0], 1, 2, True),   # Test 2 (padded)
        ([2,3,2,3,6,8,9,0], 3, 3, True),   # Test 3 (padded and fixed)
        ([5,5,5,5,5,5,5,5], 5, 7, True),   # Max position edge case
        ([1,2,3,4,5,6,7,8], 9, 0, False)   # Not found case
    ]
    
    passed = 0
    for arr, target, exp_idx, exp_found in test_cases:
        # Load array
        for i in range(8):
            dut.arr[i].value = arr[i]
        dut.target.value = target
        
        # Start search
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        if dut.found.value == exp_found:
            if not exp_found or (dut.position.value == exp_idx):
                passed += 1
                dut._log.info(f"PASS: {arr} target={target} => idx={dut.position.value}, found={dut.found.value}")
            else:
                dut._log.error(f"FAIL: {arr} target={target} => idx={dut.position.value} (expected {exp_idx}), found={dut.found.value}")
        else:
            dut._log.error(f"FAIL: {arr} target={target} => found={dut.found.value} (expected {exp_found})")
        
        await RisingEdge(dut.clk)
        
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} tests passed")