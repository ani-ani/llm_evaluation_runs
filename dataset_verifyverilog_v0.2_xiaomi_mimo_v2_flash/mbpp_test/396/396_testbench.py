import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_check_string_char(dut):
    """Test if string starts and ends with same character"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.last_in.value = 0
    dut.char_in.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to feed a string
    async def feed_string(s):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for i, char in enumerate(s):
            dut.char_in.value = ord(char)
            dut.valid_in.value = 1
            dut.last_in.value = 1 if i == len(s) - 1 else 0
            await RisingEdge(dut.clk)
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        return int(dut.result.value)
    
    # Test 1: "abba" - Valid (starts with 'a', ends with 'a')
    result = await feed_string("abba")
    assert result == 1, f"Test 1 failed: abba expected 1 (Valid), got {result}"
    print("Test 1 passed: abba = Valid")
    
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test 2: "a" - Valid (single character)
    result = await feed_string("a")
    assert result == 1, f"Test 2 failed: a expected 1 (Valid), got {result}"
    print("Test 2 passed: a = Valid")
    
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test 3: "abcd" - Invalid (starts with 'a', ends with 'd')
    result = await feed_string("abcd")
    assert result == 0, f"Test 3 failed: abcd expected 0 (Invalid), got {result}"
    print("Test 3 passed: abcd = Invalid")
    
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Additional test: "racecar" - Valid
    result = await feed_string("racecar")
    assert result == 1, f"Additional test failed: racecar expected 1 (Valid), got {result}"
    print("Additional test passed: racecar = Valid")
    
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Additional test: "hello" - Invalid
    result = await feed_string("hello")
    assert result == 0, f"Additional test failed: hello expected 0 (Invalid), got {result}"
    print("Additional test passed: hello = Invalid")
    
    print("
=== Summary ===")
    print("5/5 tests passed")