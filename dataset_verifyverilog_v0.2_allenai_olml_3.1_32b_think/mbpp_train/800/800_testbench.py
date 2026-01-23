import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_remove_all_spaces(dut):
    """Test remove_all_spaces module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.input_valid.value = 0
    dut.input_done.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 'python  program' -> 'pythonprogram'
    # Input: 16 chars (14 + 2 spaces)
    test_input1 = b'python  program'
    expected_output1 = b'pythonprogram'
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed input characters
    for char in test_input1:
        dut.char_in.value = char
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    dut.input_done.value = 0
    
    # Collect output
    output_chars = []
    timeout = 50
    
    while timeout > 0:
        await RisingEdge(dut.clk)
        if dut.output_valid.value == 1:
            output_chars.append(int(dut.output_char.value))
        if dut.done.value == 1:
            break
        timeout -= 1
    
    output_bytes = bytes(output_chars)
    print(f"Test 1: Input='{test_input1.decode()}' Expected='{expected_output1.decode()}' Got='{output_bytes.decode()}'")
    assert output_bytes == expected_output1, f"Test 1 failed: expected {expected_output1}, got {output_bytes}"
    
    # Test case 2: 'python   programming    language' -> 'pythonprogramminglanguage'
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_input2 = b'python   programming    language'
    expected_output2 = b'pythonprogramminglanguage'
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in test_input2:
        dut.char_in.value = char
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    dut.input_done.value = 0
    
    output_chars = []
    timeout = 100
    
    while timeout > 0:
        await RisingEdge(dut.clk)
        if dut.output_valid.value == 1:
            output_chars.append(int(dut.output_char.value))
        if dut.done.value == 1:
            break
        timeout -= 1
    
    output_bytes = bytes(output_chars)
    print(f"Test 2: Input='{test_input2.decode()}' Expected='{expected_output2.decode()}' Got='{output_bytes.decode()}'")
    assert output_bytes == expected_output2, f"Test 2 failed: expected {expected_output2}, got {output_bytes}"
    
    # Test case 3: 'python                     program' -> 'pythonprogram'
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_input3 = b'python                     program'
    expected_output3 = b'pythonprogram'
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in test_input3:
        dut.char_in.value = char
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    dut.input_done.value = 0
    
    output_chars = []
    timeout = 100
    
    while timeout > 0:
        await RisingEdge(dut.clk)
        if dut.output_valid.value == 1:
            output_chars.append(int(dut.output_char.value))
        if dut.done.value == 1:
            break
        timeout -= 1
    
    output_bytes = bytes(output_chars)
    print(f"Test 3: Input='{test_input3.decode()}' Expected='{expected_output3.decode()}' Got='{output_bytes.decode()}'")
    assert output_bytes == expected_output3, f"Test 3 failed: expected {expected_output3}, got {output_bytes}"
    
    # Test case 4: '   python                     program' -> 'pythonprogram'
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_input4 = b'   python                     program'
    expected_output4 = b'pythonprogram'
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in test_input4:
        dut.char_in.value = char
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    dut.input_done.value = 0
    
    output_chars = []
    timeout = 100
    
    while timeout > 0:
        await RisingEdge(dut.clk)
        if dut.output_valid.value == 1:
            output_chars.append(int(dut.output_char.value))
        if dut.done.value == 1:
            break
        timeout -= 1
    
    output_bytes = bytes(output_chars)
    print(f"Test 4: Input='{test_input4.decode()}' Expected='{expected_output4.decode()}' Got='{output_bytes.decode()}'")
    assert output_bytes == expected_output4, f"Test 4 failed: expected {expected_output4}, got {output_bytes}"
    
    print("
All 4 tests passed!")
