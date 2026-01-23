import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_encrypt_basic(dut):
    """Test basic encryption functionality."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.len.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: "hi" -> "lm"
    # 'h' (0x68) + 4 = 0x6C ('l')
    # 'i' (0x69) + 4 = 0x6D ('m')
    test_string = "hi"
    dut.len.value = len(test_string)
    
    # Start encryption
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    output_chars = []
    
    # Process each character
    for i, char in enumerate(test_string):
        # Feed input character
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)  # Allow processing
        
        # Wait for valid output
        timeout = 0
        while timeout < 50:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.out_valid.value) and dut.out_valid.value == 1:
                if is_value_defined(dut.char_out.value):
                    output_chars.append(chr(int(dut.char_out.value)))
                break
            timeout += 1
        else:
            raise TestFailure(f"Timeout waiting for output valid for char '{char}'")
    
    # Wait for done
    timeout = 0
    while timeout < 20:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        timeout += 1
    else:
        raise TestFailure("Done signal did not go high")
    
    result = ''.join(output_chars)
    dut._log.info(f"Input: '{test_string}' -> Output: '{result}'")
    if result != "lm":
        raise TestFailure(f"Expected 'lm', got '{result}'")

@cocotb.test(timeout_time=3, timeout_unit="ms")
async def test_encrypt_longer(dut):
    """Test longer string encryption."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: "asdfghjkl" -> "ewhjklnop"
    test_string = "asdfghjkl"
    dut.len.value = len(test_string)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    output_chars = []
    
    for char in test_string:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        timeout = 0
        while timeout < 50:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.out_valid.value) and dut.out_valid.value == 1:
                if is_value_defined(dut.char_out.value):
                    output_chars.append(chr(int(dut.char_out.value)))
                break
            timeout += 1
        else:
            raise TestFailure(f"Timeout for char '{char}'")
    
    # Wait for done
    timeout = 0
    while timeout < 20:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        timeout += 1
    else:
        raise TestFailure("Done signal did not go high")
    
    result = ''.join(output_chars)
    dut._log.info(f"Input: '{test_string}' -> Output: '{result}'")
    if result != "ewhjklnop":
        raise TestFailure(f"Expected 'ewhjklnop', got '{result}'")

@cocotb.test(timeout_time=3, timeout_unit="ms")
async def test_encrypt_edge_cases(dut):
    """Test edge cases: single char, wrap-around."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: [(input, expected), ...]
    test_cases = [
        ('gf', 'kj'),
        ('et', 'ix'),
        ('a', 'e'),  # Wrap check: 'z' + 4 = 'd', 'y' + 4 = 'c', 'w' + 4 = 'a'
        ('w', 'a'),  # 'w' (0x77) + 4 = 0x7B -> should wrap to 'a' (0x61) or 'A' logic
        ('W', 'A'),  # 'W' (0x57) + 4 = 0x5B -> wrap to 'A' (0x41)
    ]
    
    for test_input, expected in test_cases:
        dut.len.value = len(test_input)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        output_chars = []
        
        for char in test_input:
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            
            timeout = 0
            while timeout < 50:
                await RisingEdge(dut.clk)
                if is_value_defined(dut.out_valid.value) and dut.out_valid.value == 1:
                    if is_value_defined(dut.char_out.value):
                        output_chars.append(chr(int(dut.char_out.value)))
                    break
                timeout += 1
            else:
                raise TestFailure(f"Timeout for '{char}' in '{test_input}'")
        
        # Wait for done
        timeout = 0
        while timeout < 20:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
            timeout += 1
        else:
            raise TestFailure(f"Done failed for '{test_input}'")
        
        result = ''.join(output_chars)
        if result != expected:
            raise TestFailure(f"Input '{test_input}': expected '{expected}', got '{result}'")
        dut._log.info(f"Passed: '{test_input}' -> '{result}'")

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_encrypt_non_alpha(dut):
    """Test non-alphabetic characters (should pass through)."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_input = "ab12cd"
    dut.len.value = len(test_input)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Expected: 'a'->'e', 'b'->'f', '1'->'1', '2'->'2', 'c'->'g', 'd'->'h'
    expected = "ef12gh"
    output_chars = []
    
    for char in test_input:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        timeout = 0
        while timeout < 50:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.out_valid.value) and dut.out_valid.value == 1:
                if is_value_defined(dut.char_out.value):
                    output_chars.append(chr(int(dut.char_out.value)))
                break
            timeout += 1
        else:
            raise TestFailure(f"Timeout for char '{char}'")
    
    # Wait for done
    timeout = 0
    while timeout < 20:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        timeout += 1
    else:
        raise TestFailure("Done signal did not go high")
    
    result = ''.join(output_chars)
    if result != expected:
        raise TestFailure(f"Expected '{expected}', got '{result}'")
    dut._log.info(f"Non-alpha test passed: '{test_input}' -> '{result}'")
