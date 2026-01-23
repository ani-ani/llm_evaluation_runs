import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def ascii(char):
    return ord(char)

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_histogram(dut):
    """Test the histogram module with various input strings."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_chars.value = 0
    for i in range(8):
        dut.str_in[i].value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    # Each case: (input_string, expected_char, expected_count)
    # Input string is padded to 8 chars with spaces (0x20) or nulls
    test_cases = [
        ("a b b a", 'a', 2),    # Or 'b', but 'a' is first
        ("a b c a b", 'a', 2),  # Or 'b'
        ("a b c d g", 'a', 1),  # First char
        ("r t g", 'r', 1),      # First char
        ("b b b b a", 'b', 4),
        ("", ' ', 0),          # Empty string
        ("a", 'a', 1),
    ]
    
    for test_idx, (input_str, expected_char, expected_count) in enumerate(test_cases):
        dut._log.info(f"Test {test_idx}: Input '{input_str}'")
        
        # Prepare input array
        # We need to handle spaces: the input string is space separated characters
        # The function receives a string like "a b b a"
        # We will filter spaces and take first 8 chars
        chars = [c for c in input_str if c != ' ']
        # Pad to 8 with 0x00 or 0x20? Let's use 0x00 for unused
        
        # Fill the dut array
        for i in range(8):
            if i < len(chars):
                dut.str_in[i].value = ascii(chars[i])
            else:
                dut.str_in[i].value = 0x00
        
        dut.valid_chars.value = len(chars)
        
        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        max_cycles = 100
        done_found = False
        for cycle in range(max_cycles):
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
            await RisingEdge(dut.clk)
        
        if not done_found:
            raise TestFailure(f"Test {test_idx}: Timeout waiting for done signal")
        
        # Check output
        if not is_value_defined(dut.result_char.value) or not is_value_defined(dut.result_count.value):
            raise TestFailure(f"Test {test_idx}: Output is undefined (X/Z)")
        
        actual_char_val = int(dut.result_char.value)
        actual_count = int(dut.result_count.value)
        
        # Convert actual char to ASCII if valid
        actual_char = chr(actual_char_val) if actual_char_val != 0 else '\0'
        
        # Handle empty string case (count 0)
        if expected_count == 0:
            if actual_count != 0:
                raise TestFailure(f"Test {test_idx}: Expected count 0, got {actual_count}")
            # Char can be anything when count is 0, usually 0
            dut._log.info(f"Test {test_idx} passed: count={actual_count}")
            continue
            
        # For non-empty, check count matches and char is one of the expected ones
        # Note: If multiple chars have same max count, any is valid. 
        # We must verify the count is correct and the char exists in input.
        
        if actual_count != expected_count:
             # Try to see if it matches 'b' in the a/b cases
             # The original python function returns all max keys, hardware picks one.
             # We just check if count is correct.
             raise TestFailure(f"Test {test_idx}: Expected count {expected_count}, got {actual_count}")
        
        # Check if the character is valid (appears in input string)
        # Since we pick 'first max', it should usually match our manual expectation or be the other max char
        if actual_char not in chars:
             # It might be 0x00 if string is empty (handled above) or logic error
             # Or space (0x20) if we counted spaces (we filtered them, so shouldn't)
             raise TestFailure(f"Test {test_idx}: Result char '{actual_char}' (0x{actual_char_val:02X}) not found in input '{input_str}'")
        
        dut._log.info(f"Test {test_idx} passed: char='{actual_char}', count={actual_count}")
    
    dut._log.info("All tests passed [OK]")
