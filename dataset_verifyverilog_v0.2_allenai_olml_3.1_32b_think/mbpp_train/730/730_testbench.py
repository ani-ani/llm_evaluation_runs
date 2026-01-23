import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_remove_consecutive_duplicates(dut):
    """Test consecutive duplicate removal"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_length.value = 0
    for i in range(16):
        dut.input_data[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [0,0,1,2,3,4,4,5,6,6,6,7,8,9,4,4] -> [0,1,2,3,4,5,6,7,8,9,4] (length 11)
    dut.input_length.value = 16
    test_input1 = [0,0,1,2,3,4,4,5,6,6,6,7,8,9,4,4]
    for i, val in enumerate(test_input1):
        dut.input_data[i].value = val
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 20 cycles)
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "done signal should be high"
    assert dut.output_length.value == 11, f"Expected output length 11, got {int(dut.output_length.value)}"
    expected1 = [0,1,2,3,4,5,6,7,8,9,4]
    for i in range(11):
        assert dut.output_data[i].value == expected1[i], f"Index {i}: expected {expected1[i]}, got {int(dut.output_data[i].value)}"
    print("Test 1 passed")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: [10,10,15,19,18,18,17,26,26,17,18,10] -> [10,15,19,18,17,26,17,18,10] (length 9)
    dut.input_length.value = 12
    test_input2 = [10,10,15,19,18,18,17,26,26,17,18,10]
    for i, val in enumerate(test_input2):
        dut.input_data[i].value = val
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.output_length.value == 9, f"Expected 9, got {int(dut.output_length.value)}"
    expected2 = [10,15,19,18,17,26,17,18,10]
    for i in range(9):
        assert dut.output_data[i].value == expected2[i], f"Index {i}: expected {expected2[i]}, got {int(dut.output_data[i].value)}"
    print("Test 2 passed")
    
    # Test 3: [97,97,98,99,100,100] -> [97,98,99,100] (length 4) (ASCII for 'a','a','b','c','d','d')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.input_length.value = 6
    test_input3 = [97,97,98,99,100,100]  # 'a','a','b','c','d','d'
    for i, val in enumerate(test_input3):
        dut.input_data[i].value = val
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.output_length.value == 4, f"Expected 4, got {int(dut.output_length.value)}"
    expected3 = [97,98,99,100]
    for i in range(4):
        assert dut.output_data[i].value == expected3[i], f"Index {i}: expected {expected3[i]}, got {int(dut.output_data[i].value)}"
    print("Test 3 passed")
    
    # Test 4: [97,97,98,99,100,100,97,97] -> [97,98,99,100,97] (length 5)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.input_length.value = 8
    test_input4 = [97,97,98,99,100,100,97,97]
    for i, val in enumerate(test_input4):
        dut.input_data[i].value = val
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.output_length.value == 5, f"Expected 5, got {int(dut.output_length.value)}"
    expected4 = [97,98,99,100,97]
    for i in range(5):
        assert dut.output_data[i].value == expected4[i], f"Index {i}: expected {expected4[i]}, got {int(dut.output_data[i].value)}"
    print("Test 4 passed")
    
    print("All 4 tests passed!")