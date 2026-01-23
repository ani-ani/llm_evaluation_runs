import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_substring_search(dut):
    """Test substring search module with various test cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_data.value = 0
    dut.str_idx.value = 0
    dut.char_idx.value = 0
    dut.substr_len.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to load substring
    async def load_substring(substr):
        dut._log.info(f"Loading substring: '{substr}'")
        for i, char in enumerate(substr):
            dut.str_data.value = ord(char)
            dut.char_idx.value = i
            await RisingEdge(dut.clk)
        dut.substr_len.value = len(substr)
    
    # Helper function to load and check a string
    async def check_string(str_idx, string, max_len=8):
        dut._log.info(f"Checking string {str_idx}: '{string}'")
        dut.str_idx.value = str_idx
        # Load each character
        for i in range(max_len):
            if i < len(string):
                dut.str_data.value = ord(string[i])
            else:
                dut.str_data.value = 0  # padding
            dut.char_idx.value = i
            await RisingEdge(dut.clk)
    
    # Test 1: "ack" in "black" - should find
    dut._log.info("
=== Test 1: Should find 'ack' ===")
    await load_substring("ack")
    
    # Process all 5 strings
    strings = ["red", "black", "white", "green", "orange"]
    for i, s in enumerate(strings):
        await check_string(i, s)
    
    # Wait for result
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done with timeout
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 300:
        raise TestFailure("Test 1 timed out")
    
    if not dut.found.value:
        raise TestFailure(f"Test 1 failed: Expected found=1, got {dut.found.value}")
    dut._log.info("Test 1 PASSED: Substring 'ack' found")
    
    # Test 2: "abc" - should not find
    dut._log.info("
=== Test 2: Should NOT find 'abc' ===")
    dut.rst_n.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await load_substring("abc")
    for i, s in enumerate(strings):
        await check_string(i, s)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 300:
        raise TestFailure("Test 2 timed out")
    
    if dut.found.value:
        raise TestFailure(f"Test 2 failed: Expected found=0, got {dut.found.value}")
    dut._log.info("Test 2 PASSED: Substring 'abc' not found")
    
    # Test 3: "ange" in "orange" - should find
    dut._log.info("
=== Test 3: Should find 'ange' ===")
    dut.rst_n.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await load_substring("ange")
    for i, s in enumerate(strings):
        await check_string(i, s)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 300:
        raise TestFailure("Test 3 timed out")
    
    if not dut.found.value:
        raise TestFailure(f"Test 3 failed: Expected found=1, got {dut.found.value}")
    dut._log.info("Test 3 PASSED: Substring 'ange' found")
    
    # Summary
    dut._log.info("
=== Summary: 3/3 tests passed ===")
    
    # Additional edge case: exact match
    dut._log.info("
=== Bonus Test: Exact match 'green' ===")
    dut.rst_n.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await load_substring("green")
    for i, s in enumerate(strings):
        await check_string(i, s)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 300:
        raise TestFailure("Bonus test timed out")
    
    if not dut.found.value:
        raise TestFailure(f"Bonus test failed: Expected found=1, got {dut.found.value}")
    dut._log.info("Bonus test PASSED: Exact match 'green' found")
    
    dut._log.info("
=== ALL TESTS PASSED ===")
