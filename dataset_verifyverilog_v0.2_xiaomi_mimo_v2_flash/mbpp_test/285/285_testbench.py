import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_text_match_two_three(dut):
    """Test the text_match_two_three module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_index.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: "ac" -> False
    # String: 'a','c', then 6 null terminators or spaces
    # Expected: No match
    dut._log.info("Test 1: 'ac' -> False")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed 'a','c', then 6 'x' padding
    test_str1 = ['a', 'c'] + ['x'] * 6
    for i, char in enumerate(test_str1):
        dut.char_in.value = ord(char)
        dut.char_index.value = i
        await RisingEdge(dut.clk)
        if i >= 2 and dut.match.value == 1:
            dut._log.info(f"Match detected at index {i}")
    
    await RisingEdge(dut.clk)
    if dut.match.value == 1:
        raise TestFailure("Test 1 failed: Expected no match but got match")
    if dut.done.value != 1:
        raise TestFailure("Test 1 failed: Expected done high")
    
    # Wait a bit
    await RisingEdge(dut.clk)
    
    # Test case 2: "dc" -> False
    # Expected: No match
    dut._log.info("Test 2: 'dc' -> False")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_str2 = ['d', 'c'] + ['x'] * 6
    for i, char in enumerate(test_str2):
        dut.char_in.value = ord(char)
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    if dut.match.value == 1:
        raise TestFailure("Test 2 failed: Expected no match but got match")
    if dut.done.value != 1:
        raise TestFailure("Test 2 failed: Expected done high")
    
    # Wait a bit
    await RisingEdge(dut.clk)
    
    # Test case 3: "abbbba" -> True
    # String: 'a','b','b','b','b','a', then 2 padding
    # This contains 'a' + 3 'b's (positions 0-3) AND 'a' + 2 'b's (positions 4-5 is 'b','a' not, but positions 0-2 is 'a','b','b')
    # Actually 'abbbba' has 'a','b','b','b','b','a' - at position 0 we get 'a' + 4 'b's
    # The pattern requires 2 OR 3 b's, so 'a' + 4 'b's qualifies (since it contains a + 3 b's)
    dut._log.info("Test 3: 'abbbba' -> True")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_str3 = ['a', 'b', 'b', 'b', 'b', 'a'] + ['x'] * 2
    for i, char in enumerate(test_str3):
        dut.char_in.value = ord(char)
        dut.char_index.value = i
        await RisingEdge(dut.clk)
        if dut.match.value == 1:
            dut._log.info(f"Match detected at index {i}")
    
    await RisingEdge(dut.clk)
    if dut.match.value != 1:
        raise TestFailure("Test 3 failed: Expected match but got no match")
    if dut.done.value != 1:
        raise TestFailure("Test 3 failed: Expected done high")
    
    # Additional test case 4: "abb" -> True
    dut._log.info("Additional Test 4: 'abb' -> True")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_str4 = ['a', 'b', 'b'] + ['x'] * 5
    for i, char in enumerate(test_str4):
        dut.char_in.value = ord(char)
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    if dut.match.value != 1:
        raise TestFailure("Test 4 failed: Expected match but got no match")
    
    # Additional test case 5: "abbbb" -> True (contains abbb)
    dut._log.info("Additional Test 5: 'abbbb' -> True")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_str5 = ['a', 'b', 'b', 'b', 'b'] + ['x'] * 3
    for i, char in enumerate(test_str5):
        dut.char_in.value = ord(char)
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    if dut.match.value != 1:
        raise TestFailure("Test 5 failed: Expected match but got no match")
    
    dut._log.info("All tests completed!")
