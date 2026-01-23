import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_remove_parenthesis_basic(dut):
    """Test basic parenthesis removal"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: "a(b)c\0" -> "ac\0"
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Send string character by character
    test_string = "a(b)c"
    expected_output = "ac"
    output_idx = 0
    
    for char in test_string:
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        
        # Check output
        if dut.char_out_valid.value == 1:
            if output_idx >= len(expected_output):
                raise TestFailure(f"Unexpected output character at position {output_idx}")
            if dut.char_out.value != ord(expected_output[output_idx]):
                raise TestFailure(f"Expected '{expected_output[output_idx]}', got '{chr(int(dut.char_out.value))}'")
            output_idx += 1
    
    # Send null terminator
    dut.char_in.value = 0
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    
    # Check null is output
    if dut.char_out_valid.value == 1:
        if dut.char_out.value != 0:
            raise TestFailure(f"Expected null terminator, got {int(dut.char_out.value)}")
    
    if not dut.done.value:
        raise TestFailure("Done signal not high after null terminator")
    
    dut._log.info("Test 1 passed: 'a(b)c' -> 'ac'")

@cocotb.test()
async def test_remove_parenthesis_no_parens(dut):
    """Test string with no parentheses"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_string = "no parens"
    expected_output = test_string
    output_idx = 0
    
    for char in test_string:
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        
        if dut.char_out_valid.value == 1:
            if output_idx >= len(expected_output):
                raise TestFailure(f"Unexpected output at position {output_idx}")
            if dut.char_out.value != ord(expected_output[output_idx]):
                raise TestFailure(f"Expected '{expected_output[output_idx]}', got '{chr(int(dut.char_out.value))}'")
            output_idx += 1
    
    dut.char_in.value = 0
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Done signal not high")
    
    dut._log.info("Test 2 passed: 'no parens' -> 'no parens'")

@cocotb.test()
async def test_remove_parenthesis_leading_paren(dut):
    """Test string starting with parentheses"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_string = "(start)end"
    expected_output = "end"
    output_idx = 0
    
    for char in test_string:
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        
        if dut.char_out_valid.value == 1:
            if output_idx >= len(expected_output):
                raise TestFailure(f"Unexpected output at position {output_idx}")
            if dut.char_out.value != ord(expected_output[output_idx]):
                raise TestFailure(f"Expected '{expected_output[output_idx]}', got '{chr(int(dut.char_out.value))}'")
            output_idx += 1
    
    dut.char_in.value = 0
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Done signal not high")
    
    dut._log.info("Test 3 passed: '(start)end' -> 'end'")

@cocotb.test()
async def test_remove_parenthesis_multiple_groups(dut):
    """Test string with multiple parenthetical groups"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_string = "multi(parens)here(more)"
    expected_output = "multihere"
    output_idx = 0
    
    for char in test_string:
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        
        if dut.char_out_valid.value == 1:
            if output_idx >= len(expected_output):
                raise TestFailure(f"Unexpected output at position {output_idx}")
            if dut.char_out.value != ord(expected_output[output_idx]):
                raise TestFailure(f"Expected '{expected_output[output_idx]}', got '{chr(int(dut.char_out.value))}'")
            output_idx += 1
    
    dut.char_in.value = 0
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Done signal not high")
    
    dut._log.info("Test 4 passed: 'multi(parens)here(more)' -> 'multihere'")

@cocotb.test()
async def test_remove_parenthesis_all_parens(dut):
    """Test string with only parentheses"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_string = "(all)"
    expected_output = ""
    output_idx = 0
    
    for char in test_string:
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        
        if dut.char_out_valid.value == 1:
            if output_idx >= len(expected_output):
                raise TestFailure(f"Unexpected output at position {output_idx}")
            if dut.char_out.value != ord(expected_output[output_idx]):
                raise TestFailure(f"Expected null, got '{chr(int(dut.char_out.value))}'")
            output_idx += 1
    
    dut.char_in.value = 0
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Done signal not high")
    
    dut._log.info("Test 5 passed: '(all)' -> ''")
    
    # Summary
    total_tests = 5
    passed_tests = 0
    for test in cocotb.test("test_remove_parenthesis_basic", test_remove_parenthesis_basic), \
                 cocotb.test("test_remove_parenthesis_no_parens", test_remove_parenthesis_no_parens), \
                 cocotb.test("test_remove_parenthesis_leading_paren", test_remove_parenthesis_leading_paren), \
                 cocotb.test("test_remove_parenthesis_multiple_groups", test_remove_parenthesis_multiple_groups), \
                 cocotb.test("test_remove_parenthesis_all_parens", test_remove_parenthesis_all_parens):
        passed_tests += 1
    dut._log.info(f"
Summary: {passed_tests}/{total_tests} tests passed")