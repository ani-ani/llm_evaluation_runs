import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_odd_xor_pairs(dut):
    """Test counting pairs with odd XOR"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.valid.value = 0
    dut.done.value = 0
    dut.data_i.value = 0
    dut.idx.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [5,4,7,2,1] -> 6 pairs
    dut._log.info("Test 1: [5,4,7,2,1]")
    # 5(odd),4(even),7(odd),2(even),1(odd) -> 3 odd, 2 even -> 3*2=6
    await RisingEdge(dut.clk)
    
    # Provide elements
    test1_data = [5,4,7,2,1]
    for i, val in enumerate(test1_data):
        dut.data_i.value = val
        dut.idx.value = i
        dut.valid.value = 1
        dut.done.value = 0
        await RisingEdge(dut.clk)
    
    # Signal done
    dut.valid.value = 0
    dut.done.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.result.value != 6:
        raise TestFailure(f"Test 1 failed: expected 6, got {int(dut.result.value)}")
    if not dut.ready.value:
        raise TestFailure("Test 1: ready should be high")
    
    dut._log.info(f"Test 1 passed: {int(dut.result.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: [7,2,8,1,0,5,11] -> 12 pairs
    dut._log.info("Test 2: [7,2,8,1,0,5,11]")
    # 7(odd),2(even),8(even),1(odd),0(even),5(odd),11(odd)
    # 4 odd, 3 even -> 4*3=12
    
    test2_data = [7,2,8,1,0,5,11]
    for i, val in enumerate(test2_data):
        dut.data_i.value = val
        dut.idx.value = i
        dut.valid.value = 1
        dut.done.value = 0
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.done.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.result.value != 12:
        raise TestFailure(f"Test 2 failed: expected 12, got {int(dut.result.value)}")
    
    dut._log.info(f"Test 2 passed: {int(dut.result.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: [1,2,3] -> 2 pairs
    dut._log.info("Test 3: [1,2,3]")
    # 1(odd),2(even),3(odd) -> 2 odd, 1 even -> 2*1=2
    
    test3_data = [1,2,3]
    for i, val in enumerate(test3_data):
        dut.data_i.value = val
        dut.idx.value = i
        dut.valid.value = 1
        dut.done.value = 0
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.done.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.result.value != 2:
        raise TestFailure(f"Test 3 failed: expected 2, got {int(dut.result.value)}")
    
    dut._log.info(f"Test 3 passed: {int(dut.result.value)}")
    
    # Additional edge case: All even [2,4,6] -> 0 pairs
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 4: [2,4,6] (all even)")
    test4_data = [2,4,6]
    for i, val in enumerate(test4_data):
        dut.data_i.value = val
        dut.idx.value = i
        dut.valid.value = 1
        dut.done.value = 0
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.done.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 4 failed: expected 0, got {int(dut.result.value)}")
    
    dut._log.info(f"Test 4 passed: {int(dut.result.value)}")
    
    # Additional edge case: All odd [1,3,5] -> 0 pairs
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 5: [1,3,5] (all odd)")
    test5_data = [1,3,5]
    for i, val in enumerate(test5_data):
        dut.data_i.value = val
        dut.idx.value = i
        dut.valid.value = 1
        dut.done.value = 0
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.done.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 5 failed: expected 0, got {int(dut.result.value)}")
    
    dut._log.info(f"Test 5 passed: {int(dut.result.value)}")
    
    dut._log.info("All 5 tests passed!")
