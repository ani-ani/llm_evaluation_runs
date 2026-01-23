import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_cumulative_sum(dut):
    """Test cumulative sum of tuple list"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await Timer(25, units='ns')
    
    # Test 1: [(1, 3), (5, 6, 7), (2, 6)] = 30
    dut.tuple1_elem0.value = 1
    dut.tuple1_elem1.value = 3
    dut.tuple2_elem0.value = 5
    dut.tuple2_elem1.value = 6
    dut.tuple2_elem2.value = 7
    dut.tuple3_elem0.value = 2
    dut.tuple3_elem1.value = 6
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (9 cycles total)
    for _ in range(8):
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)  # Final cycle with done=1
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 30, f"Expected 30, got {dut.result.value}"
    print(f"Test 1 passed: result = {dut.result.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await Timer(25, units='ns')
    
    # Test 2: [(2, 4), (6, 7, 8), (3, 7)] = 37
    dut.tuple1_elem0.value = 2
    dut.tuple1_elem1.value = 4
    dut.tuple2_elem0.value = 6
    dut.tuple2_elem1.value = 7
    dut.tuple2_elem2.value = 8
    dut.tuple3_elem0.value = 3
    dut.tuple3_elem1.value = 7
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(8):
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 37, f"Expected 37, got {dut.result.value}"
    print(f"Test 2 passed: result = {dut.result.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await Timer(25, units='ns')
    
    # Test 3: [(3, 5), (7, 8, 9), (4, 8)] = 44
    dut.tuple1_elem0.value = 3
    dut.tuple1_elem1.value = 5
    dut.tuple2_elem0.value = 7
    dut.tuple2_elem1.value = 8
    dut.tuple2_elem2.value = 9
    dut.tuple3_elem0.value = 4
    dut.tuple3_elem1.value = 8
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(8):
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 44, f"Expected 44, got {dut.result.value}"
    print(f"Test 3 passed: result = {dut.result.value}")
    
    # Test 4: Edge case with zeros [(0, 0), (0, 0, 0), (0, 0)] = 0
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await Timer(25, units='ns')
    
    dut.tuple1_elem0.value = 0
    dut.tuple1_elem1.value = 0
    dut.tuple2_elem0.value = 0
    dut.tuple2_elem1.value = 0
    dut.tuple2_elem2.value = 0
    dut.tuple3_elem0.value = 0
    dut.tuple3_elem1.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(8):
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 0, f"Expected 0, got {dut.result.value}"
    print(f"Test 4 passed: result = {dut.result.value}")
    
    # Test 5: Edge case with max values [(255, 255), (255, 255, 255), (255, 255)] = 1785
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await Timer(25, units='ns')
    
    dut.tuple1_elem0.value = 255
    dut.tuple1_elem1.value = 255
    dut.tuple2_elem0.value = 255
    dut.tuple2_elem1.value = 255
    dut.tuple2_elem2.value = 255
    dut.tuple3_elem0.value = 255
    dut.tuple3_elem1.value = 255
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(8):
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 1785, f"Expected 1785, got {dut.result.value}"
    print(f"Test 5 passed: result = {dut.result.value}")
    
    print("
5/5 tests passed")