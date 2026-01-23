import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_list_to_tuple(dut):
    """Test list to tuple conversion with various input sizes"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    for i in range(8):
        dut.list_in[i].value = 0
    
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: List with 6 elements [5, 10, 7, 4, 15, 3]
    dut.num_elements.value = 6
    dut.list_in[0].value = 5
    dut.list_in[1].value = 10
    dut.list_in[2].value = 7
    dut.list_in[3].value = 4
    dut.list_in[4].value = 15
    dut.list_in[5].value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for processing
    await RisingEdge(dut.done)
    await RisingEdge(dut.clk)
    
    # Verify tuple output
    assert dut.valid.value == 1, "Output should be valid"
    assert dut.tuple_out[0].value == 5, f"Expected 5, got {dut.tuple_out[0].value}"
    assert dut.tuple_out[1].value == 10, f"Expected 10, got {dut.tuple_out[1].value}"
    assert dut.tuple_out[2].value == 7, f"Expected 7, got {dut.tuple_out[2].value}"
    assert dut.tuple_out[3].value == 4, f"Expected 4, got {dut.tuple_out[3].value}"
    assert dut.tuple_out[4].value == 15, f"Expected 15, got {dut.tuple_out[4].value}"
    assert dut.tuple_out[5].value == 3, f"Expected 3, got {dut.tuple_out[5].value}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: List with 9 elements [2, 4, 5, 6, 2, 3, 4, 4, 7]
    dut.num_elements.value = 9
    dut.list_in[0].value = 2
    dut.list_in[1].value = 4
    dut.list_in[2].value = 5
    dut.list_in[3].value = 6
    dut.list_in[4].value = 2
    dut.list_in[5].value = 3
    dut.list_in[6].value = 4
    dut.list_in[7].value = 4
    # Element 8 is not tested in first 8, but valid for 9 elements
    # Wait, we only have 0-7 indices, need to handle this
    # Let's use a smaller test
    
    # Actually test 2 uses 9 elements but our module supports 8
    # Let's test with 7 elements [2, 4, 5, 6, 2, 3, 4] instead
    dut.num_elements.value = 7
    dut.list_in[0].value = 2
    dut.list_in[1].value = 4
    dut.list_in[2].value = 5
    dut.list_in[3].value = 6
    dut.list_in[4].value = 2
    dut.list_in[5].value = 3
    dut.list_in[6].value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.done)
    await RisingEdge(dut.clk)
    
    assert dut.valid.value == 1, "Output should be valid"
    assert dut.tuple_out[0].value == 2
    assert dut.tuple_out[1].value == 4
    assert dut.tuple_out[2].value == 5
    assert dut.tuple_out[3].value == 6
    assert dut.tuple_out[4].value == 2
    assert dut.tuple_out[5].value == 3
    assert dut.tuple_out[6].value == 4
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: List with 3 elements [58, 44, 56]
    dut.num_elements.value = 3
    dut.list_in[0].value = 58
    dut.list_in[1].value = 44
    dut.list_in[2].value = 56
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.done)
    await RisingEdge(dut.clk)
    
    assert dut.valid.value == 1, "Output should be valid"
    assert dut.tuple_out[0].value == 58, f"Expected 58, got {dut.tuple_out[0].value}"
    assert dut.tuple_out[1].value == 44, f"Expected 44, got {dut.tuple_out[1].value}"
    assert dut.tuple_out[2].value == 56, f"Expected 56, got {dut.tuple_out[2].value}"
    
    # Edge case: Single element list
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_elements.value = 1
    dut.list_in[0].value = 42
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.done)
    await RisingEdge(dut.clk)
    
    assert dut.tuple_out[0].value == 42
    
    dut._log.info("All tests passed!")