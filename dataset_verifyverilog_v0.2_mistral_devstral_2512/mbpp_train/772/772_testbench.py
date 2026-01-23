import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_remove_length_basic(dut):
    """Test basic functionality with K=3"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_len.value = 0
    dut.input_str.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 'The person is most value tet' with K=3
    # Expected output: 'person is most value' (padded to 16 chars)
    input_str = 'The person is most value tet'
    # Pad to 16 characters
    padded_input = input_str.ljust(16)
    dut.input_str.value = int.from_bytes(padded_input.encode('ascii'), 'big')
    dut.k_len.value = 3
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300, "Timeout waiting for done"
    assert dut.valid.value == 1, "Output should be valid"
    
    # Get output and decode
    output_val = dut.output_str.value
    output_bytes = output_val.to_bytes(16, 'big')
    output_str = output_bytes.decode('ascii')
    expected = 'person is most value'.ljust(16)
    
    print(f"Input: '{input_str}'")
    print(f"K=3")
    print(f"Output: '{output_str}'")
    print(f"Expected: '{expected}'")
    
    assert output_str == expected, f"Output mismatch: got '{output_str}' expected '{expected}'"

@cocotb.test()
async def test_remove_length_four(dut):
    """Test with K=4"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_len.value = 0
    dut.input_str.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 'If you told me about this ok' with K=4
    # Expected: 'If you me about ok'
    input_str = 'If you told me about this ok'
    padded_input = input_str.ljust(16)
    dut.input_str.value = int.from_bytes(padded_input.encode('ascii'), 'big')
    dut.k_len.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300
    assert dut.valid.value == 1
    
    output_val = dut.output_str.value
    output_bytes = output_val.to_bytes(16, 'big')
    output_str = output_bytes.decode('ascii')
    expected = 'If you me about ok'.ljust(16)
    
    print(f"Input: '{input_str}'")
    print(f"K=4")
    print(f"Output: '{output_str}'")
    print(f"Expected: '{expected}'")
    
    assert output_str == expected

@cocotb.test()
async def test_remove_length_k_zero(dut):
    """Test with K=0 (no words removed)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_len.value = 0
    dut.input_str.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: remove nothing (K=0, no words have length 0)
    input_str = 'Hello world test'
    padded_input = input_str.ljust(16)
    dut.input_str.value = int.from_bytes(padded_input.encode('ascii'), 'big')
    dut.k_len.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300
    assert dut.valid.value == 1
    
    output_val = dut.output_str.value
    output_bytes = output_val.to_bytes(16, 'big')
    output_str = output_bytes.decode('ascii')
    expected = 'Hello world test'.ljust(16)
    
    print(f"Input: '{input_str}'")
    print(f"K=0")
    print(f"Output: '{output_str}'")
    print(f"Expected: '{expected}'")
    
    assert output_str == expected

@cocotb.test()
async def test_remove_length_all_filtered(dut):
    """Test when all words match K (all removed)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_len.value = 0
    dut.input_str.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: all words are length 3, K=3 -> should return all spaces
    input_str = 'cat dog rat'
    padded_input = input_str.ljust(16)
    dut.input_str.value = int.from_bytes(padded_input.encode('ascii'), 'big')
    dut.k_len.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300
    assert dut.valid.value == 1
    
    output_val = dut.output_str.value
    output_bytes = output_val.to_bytes(16, 'big')
    output_str = output_bytes.decode('ascii')
    expected = ' ' * 16
    
    print(f"Input: '{input_str}'")
    print(f"K=3")
    print(f"Output: '{output_str}'")
    print(f"Expected: '{expected}'")
    
    assert output_str == expected

@cocotb.test()
async def test_remove_length_edge_case(dut):
    """Test with K=1 and single letters"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_len.value = 0
    dut.input_str.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: 'a big cat' with K=1 -> should remove 'a', keep 'big cat'
    input_str = 'a big cat'
    padded_input = input_str.ljust(16)
    dut.input_str.value = int.from_bytes(padded_input.encode('ascii'), 'big')
    dut.k_len.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300
    assert dut.valid.value == 1
    
    output_val = dut.output_str.value
    output_bytes = output_val.to_bytes(16, 'big')
    output_str = output_bytes.decode('ascii')
    expected = 'big cat'.ljust(16)
    
    print(f"Input: '{input_str}'")
    print(f"K=1")
    print(f"Output: '{output_str}'")
    print(f"Expected: '{expected}'")
    
    assert output_str == expected

@cocotb.test()
async def test_remove_length_run_all(dut):
    """Run all test cases and print summary"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        ("The person is most value tet", 3, "person is most value"),
        ("If you told me about this ok", 4, "If you me about ok"),
        ("Forces of darkeness is come into the play", 4, "Forces of darkeness is the"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, K, expected) in enumerate(test_cases):
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.k_len.value = 0
        dut.input_str.value = 0
        await Timer(50, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        padded_input = input_str.ljust(16)
        dut.input_str.value = int.from_bytes(padded_input.encode('ascii'), 'big')
        dut.k_len.value = K
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 0
        while not dut.done.value and timeout < 300:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout < 300 and dut.valid.value == 1:
            output_val = dut.output_str.value
            output_bytes = output_val.to_bytes(16, 'big')
            output_str = output_bytes.decode('ascii')
            expected_padded = expected.ljust(16)
            
            if output_str == expected_padded:
                passed += 1
                print(f"Test {i+1}: PASS")
            else:
                print(f"Test {i+1}: FAIL - got '{output_str}', expected '{expected_padded}'")
        else:
            print(f"Test {i+1}: FAIL - timeout or invalid")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Expected {total} tests to pass, but only {passed} passed"
