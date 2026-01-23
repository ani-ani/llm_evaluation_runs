import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_bracket_nested_checker(dut):
    """Test the bracket nested checker module"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_array.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to load string and check result
    async def check_nested(test_string, expected):
        # Pack string into char_array (8 chars, 8 bits each)
        char_val = 0
        for i, ch in enumerate(test_string):
            if i >= 8:
                break  # Max 8 characters
            char_val |= ord(ch) << (i * 8)
        
        dut.char_array.value = char_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        result = int(dut.result.value)
        print(f"Input: '{test_string}' -> Result: {result}, Expected: {expected}")
        assert result == expected, f"Failed for '{test_string}': got {result}, expected {expected}"
        await RisingEdge(dut.clk)
    
    # Test cases
    print("
=== Running Tests ===")
    
    # Original test cases
    await check_nested('[[]]', 1)           # True
    await check_nested('[]]]]]]][[[[[]', 0) # False (invalid)
    await check_nested('[][]', 0)           # False (no nesting)
    await check_nested('[]', 0)             # False (no nesting)
    await check_nested('[[][]]', 1)         # True
    await check_nested('[[]][[', 0)         # False (unbalanced)
    await check_nested('[][][[]]', 1)       # True
    await check_nested('[[]', 0)            # False (unbalanced)
    await check_nested('[]]', 0)            # False (unbalanced)
    
    # Additional cases
    await check_nested('', 0)               # False (empty)
    await check_nested('[[[[[[[', 0)        # False (unbalanced)
    await check_nested(']]]]]]]', 0)        # False (unbalanced)
    
    # Edge cases
    await check_nested('[[[]]]', 1)         # True
    await check_nested('[[]]', 1)           # True
    await check_nested('[][][]', 0)         # False
    await check_nested('[[]][]', 1)         # True
    
    print("
=== All tests passed! ===")