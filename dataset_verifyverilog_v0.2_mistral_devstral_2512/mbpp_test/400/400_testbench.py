import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_unique_tuples(dut):
    """Test counting unique tuples"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.tuple_data.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [(3, 4), (1, 2), (4, 3), (5, 6)] -> 3 unique
    dut._log.info("Test 1: 3 unique tuples")
    dut.tuple_data[0][0].value = 3
    dut.tuple_data[0][1].value = 4
    dut.tuple_data[1][0].value = 1
    dut.tuple_data[1][1].value = 2
    dut.tuple_data[2][0].value = 4
    dut.tuple_data[2][1].value = 3
    dut.tuple_data[3][0].value = 5
    dut.tuple_data[3][1].value = 6
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (12 cycles)
    for _ in range(13):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 3, f"Expected 3 unique tuples, got {dut.result.value}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: [(4, 15), (2, 3), (5, 4), (6, 7)] -> 4 unique
    dut._log.info("Test 2: 4 unique tuples")
    dut.tuple_data[0][0].value = 4
    dut.tuple_data[0][1].value = 15
    dut.tuple_data[1][0].value = 2
    dut.tuple_data[1][1].value = 3
    dut.tuple_data[2][0].value = 5
    dut.tuple_data[2][1].value = 4
    dut.tuple_data[3][0].value = 6
    dut.tuple_data[3][1].value = 7
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(13):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 4, f"Expected 4 unique tuples, got {dut.result.value}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: [(5, 16), (2, 3), (6, 5), (6, 9)] -> 4 unique
    dut._log.info("Test 3: 4 unique tuples")
    dut.tuple_data[0][0].value = 5
    dut.tuple_data[0][1].value = 16
    dut.tuple_data[1][0].value = 2
    dut.tuple_data[1][1].value = 3
    dut.tuple_data[2][0].value = 6
    dut.tuple_data[2][1].value = 5
    dut.tuple_data[3][0].value = 6
    dut.tuple_data[3][1].value = 9
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(13):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 4, f"Expected 4 unique tuples, got {dut.result.value}"
    
    # Test 4: All duplicates [(1, 2), (1, 2), (1, 2), (1, 2)] -> 1 unique
    dut._log.info("Test 4: All duplicates")
    for i in range(4):
        dut.tuple_data[i][0].value = 1
        dut.tuple_data[i][1].value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(13):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 1, f"Expected 1 unique tuple, got {dut.result.value}"
    
    # Test 5: Edge case with max values
    dut._log.info("Test 5: Max values")
    dut.tuple_data[0][0].value = 255
    dut.tuple_data[0][1].value = 255
    dut.tuple_data[1][0].value = 255
    dut.tuple_data[1][1].value = 255
    dut.tuple_data[2][0].value = 0
    dut.tuple_data[2][1].value = 0
    dut.tuple_data[3][0].value = 255
    dut.tuple_data[3][1].value = 255
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(13):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 2, f"Expected 2 unique tuples, got {dut.result.value}"
    
    dut._log.info(f"All tests completed: 5/5 passed")