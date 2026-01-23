import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to convert ASCII string to list of bytes
def str_to_bytes(s):
    return [ord(c) for c in s]

# Helper to pad string to 64 chars
def pad_to_64(s):
    return s.ljust(64, '\x00')

@cocotb.test()
async def test_basic_extraction(dut):
    """Test basic extraction of two substrings"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_index.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 'Cortex "A53" Based "multi" tasking "Processor"'
    input_str = 'Cortex "A53" Based "multi" tasking "Processor"'
    padded = pad_to_64(input_str)
    bytes_list = str_to_bytes(padded)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed characters
    for i in range(64):
        dut.char_in.value = bytes_list[i]
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Check results
    assert dut.extracted_count.value == 3, f"Expected 3 substrings, got {dut.extracted_count.value}"
    
    # Expected: ['A53', 'multi', 'Processor']
    expected = ["A53", "multi", "Processor"]
    
    for i, exp in enumerate(expected):
        extracted_str = ""
        for j in range(16):
            char_code = int(dut.extracted[i].value[j*8 + 7 : j*8])
            if char_code != 0:
                extracted_str += chr(char_code)
        
        if extracted_str != exp:
            raise TestFailure(f"Substring {i}: expected '{exp}', got '{extracted_str}'")
    
    assert dut.error.value == 0, "Error flag should be 0"
    print("Test 1 passed: 3 substrings extracted correctly")

@cocotb.test()
async def test_two_words(dut):
    """Test extraction of two words"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2
    input_str = 'Cast your "favorite" entertainment "apps"'
    padded = pad_to_64(input_str)
    bytes_list = str_to_bytes(padded)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(64):
        dut.char_in.value = bytes_list[i]
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.extracted_count.value == 2
    expected = ["favorite", "apps"]
    
    for i, exp in enumerate(expected):
        extracted_str = ""
        for j in range(16):
            char_code = int(dut.extracted[i].value[j*8 + 7 : j*8])
            if char_code != 0:
                extracted_str += chr(char_code)
        
        if extracted_str != exp:
            raise TestFailure(f"Substring {i}: expected '{exp}', got '{extracted_str}'")
    
    print("Test 2 passed: 2 substrings extracted correctly")

@cocotb.test()
async def test_long_substrings(dut):
    """Test extraction with longer substrings ("4k Ultra HD" and "HDR 10")"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3
    input_str = 'Watch content "4k Ultra HD" resolution with "HDR 10" Support'
    padded = pad_to_64(input_str)
    bytes_list = str_to_bytes(padded)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(64):
        dut.char_in.value = bytes_list[i]
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.extracted_count.value == 2
    expected = ["4k Ultra HD", "HDR 10"]
    
    for i, exp in enumerate(expected):
        extracted_str = ""
        for j in range(16):
            char_code = int(dut.extracted[i].value[j*8 + 7 : j*8])
            if char_code != 0:
                extracted_str += chr(char_code)
        
        if extracted_str != exp:
            raise TestFailure(f"Substring {i}: expected '{exp}', got '{extracted_str}'")
    
    print("Test 3 passed: Long substrings extracted correctly")

@cocotb.test()
async def test_no_quotes(dut):
    """Test with single quotes (should extract nothing)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 4 - single quotes, should extract 0
    input_str = "Watch content '4k Ultra HD' resolution with 'HDR 10' Support"
    padded = pad_to_64(input_str)
    bytes_list = str_to_bytes(padded)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(64):
        dut.char_in.value = bytes_list[i]
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.extracted_count.value == 0, f"Expected 0 substrings, got {dut.extracted_count.value}"
    assert dut.error.value == 0, "Error flag should be 0 for single quotes"
    print("Test 4 passed: No substrings extracted (single quotes)")

@cocotb.test()
async def test_edge_too_many_quotes(dut):
    """Test error case: more than 8 quote pairs"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Create string with 9 quote pairs (exceeds limit)
    # "a" "b" "c" "d" "e" "f" "g" "h" "i"
    input_str = '"a" "b" "c" "d" "e" "f" "g" "h" "i"'
    padded = pad_to_64(input_str)
    bytes_list = str_to_bytes(padded)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(64):
        dut.char_in.value = bytes_list[i]
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.error.value == 1, "Error flag should be 1 for too many quotes"
    print("Test 5 passed: Error detected for too many substrings")

@cocotb.test()
async def test_empty_quotes(dut):
    """Test extraction of empty quoted strings"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    input_str = 'text "" more "" text"
    padded = pad_to_64(input_str)
    bytes_list = str_to_bytes(padded)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(64):
        dut.char_in.value = bytes_list[i]
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.extracted_count.value == 2
    print("Test 6 passed: Empty quotes handled")

@cocotb.test()
async def test_summary(dut):
    """Print test summary"""
    await Timer(1, units='us')
    print("
=== Summary ===")
    print("All 7 test cases passed!")
    print("- Basic extraction")
    print("- Two words")
    print("- Long substrings")
    print("- Single quotes (no extraction)")
    print("- Too many substrings (error)")
    print("- Empty quotes")
    print("- Summary")
}