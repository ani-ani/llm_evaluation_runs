import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_pattern_matcher(dut):
    """Test the pattern matcher module with various scenarios"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    dut.is_delete_file.value = 0
    dut.file_end.value = 0
    dut.files_done.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Starting tests...")
    
    # Helper function to send a string
    async def send_string(s, is_delete):
        dut.valid_in.value = 1
        dut.is_delete_file.value = 1 if is_delete else 0
        for char in s:
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
        dut.file_end.value = 1
        await RisingEdge(dut.clk)
        dut.file_end.value = 0
        dut.valid_in.value = 0
        
    # Test Case 1: Example 1 from problem
    # Input: 3 2, Files: ab, ac, cd, Delete: 1 2
    # Expected: Yes, a?
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await send_string("ab", True)   # Delete file 1
    await send_string("ac", True)   # Delete file 2
    await send_string("cd", False)  # Keep file 3
    
    dut.files_done.value = 1
    await RisingEdge(dut.clk)
    dut.files_done.value = 0
    
    # Wait for result
    while not dut.result_valid.value:
        await RisingEdge(dut.clk)
        
    assert dut.yes_no.value == 1, f"Test 1 Failed: Expected Yes (1), got {dut.yes_no.value}"
    
    # Check pattern "a?". 16-char buffer, 'a' and '?' (0x3F).
    # Pattern should be 'a' (0x61) followed by '?' (0x3F).
    pattern_str = ""
    for i in range(2):
        char_val = dut.pattern.value >> (i*8)
        char_val = char_val & 0xFF
        pattern_str += chr(char_val)
    
    print(f"Test 1 Result: Yes, Pattern: '{pattern_str}'")
    assert pattern_str[0] == 'a', f"Expected 'a', got {pattern_str[0]}"
    assert pattern_str[1] == '?', f"Expected '?', got {pattern_str[1]}"
    
    # Wait for next test (need reset or internal FSM reset logic)
    # For simplicity, let's assume we reset for next test cases
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: Example 4
    # Input: 6 3, Files: .svn, .git, ...., ..., .., ., Delete: 1 2 3
    # Expected: Yes, .???
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await send_string(".svn", True)
    await send_string(".git", True)
    await send_string("....", True)
    await send_string("...", False)
    await send_string("..", False)
    await send_string(".", False)
    
    dut.files_done.value = 1
    await RisingEdge(dut.clk)
    dut.files_done.value = 0
    
    while not dut.result_valid.value:
        await RisingEdge(dut.clk)
        
    assert dut.yes_no.value == 1, f"Test 2 Failed: Expected Yes (1), got {dut.yes_no.value}"
    
    pattern_str = ""
    for i in range(4):
        char_val = dut.pattern.value >> (i*8)
        char_val = char_val & 0xFF
        pattern_str += chr(char_val)
        
    print(f"Test 2 Result: Yes, Pattern: '{pattern_str}'")
    # Note: Hardware builds pattern from first file '.svn' -> '.', 's', 'v', 'n'
    # Second file '.git' -> different at pos 1,2,3 -> '?', '?', '?'.
    # Third file '....' -> different at pos 1,2,3 -> '?', '?', '?' (already set).
    # Result: .???.
    assert pattern_str == ".???", f"Expected '.???', got {pattern_str}"
    
    # Reset for Test 3
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: Example 3 (Failure case)
    # Input: 4 4, Files: a, b, c, dd, Delete: 1 2 3 4
    # Expected: No (length mismatch: dd has length 2, others 1)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await send_string("a", True)
    await send_string("b", True)
    await send_string("c", True)
    await send_string("dd", True)
    
    dut.files_done.value = 1
    await RisingEdge(dut.clk)
    dut.files_done.value = 0
    
    while not dut.result_valid.value:
        await RisingEdge(dut.clk)
        
    assert dut.yes_no.value == 0, f"Test 3 Failed: Expected No (0), got {dut.yes_no.value}"
    print(f"Test 3 Result: No (Correctly handled length mismatch)")
    
    # Reset for Test 4
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 4: No valid pattern (keeps matches)
    # Files: ab, ac, ad. Delete: ab, ac. Keep: ad.
    # Pattern would be a?. 'ad' matches a?. So No.
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await send_string("ab", True)
    await send_string("ac", True)
    await send_string("ad", False)
    
    dut.files_done.value = 1
    await RisingEdge(dut.clk)
    dut.files_done.value = 0
    
    while not dut.result_valid.value:
        await RisingEdge(dut.clk)
        
    assert dut.yes_no.value == 0, f"Test 4 Failed: Expected No (0), got {dut.yes_no.value}"
    print(f"Test 4 Result: No (Keep file matched pattern)")
    
    print("All tests passed!")
