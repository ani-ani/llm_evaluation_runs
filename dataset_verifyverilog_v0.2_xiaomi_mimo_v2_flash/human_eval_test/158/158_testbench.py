import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper function to convert string to 8-byte ASCII array
def str_to_bytes(s):
    bytes_list = [ord(c) for c in s[:8]]
    # Pad with zeros to length 8
    while len(bytes_list) < 8:
        bytes_list.append(0)
    return bytes_list

# Helper function to count unique characters
def count_unique(s):
    return len(set(s))

@cocotb.test()
async def test_find_max_words(dut):
    """Test find_max_words module with multiple test cases"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.word0.value = 0
    dut.word1.value = 0
    dut.word2.value = 0
    dut.word3.value = 0
    dut.word4.value = 0
    dut.word5.value = 0
    dut.word6.value = 0
    dut.word7.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from problem
    test_cases = [
        (["name", "of", "string"], "string"),
        (["name", "enam", "game"], "enam"),
        (["aaaaaaa", "bb", "cc"], "aaaaaaa"),
        (["abc", "cba"], "abc"),
        (["play", "this", "game", "of", "footbott"], "footbott"),
        (["we", "are", "gonna", "rock"], "gonna"),
        (["we", "are", "a", "mad", "nation"], "nation"),
        (["this", "is", "a", "prrk"], "this"),
        (["b"], "b"),
        (["play", "play", "play"], "play")
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (words, expected) in enumerate(test_cases):
        print(f"
Test {idx + 1}: Input {words}, Expected: '{expected}'")
        
        # Pad word list to 8 words
        words_padded = words + [""] * (8 - len(words))
        
        # Set inputs
        for i, w in enumerate(words_padded):
            byte_array = str_to_bytes(w)
            # Pack bytes into 64-bit value
            packed = 0
            for j, b in enumerate(byte_array):
                packed |= (b << (j * 8))
            setattr(dut, f"word{i}", packed)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (with timeout)
        timeout = 600  # cycles
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"  FAILED: Timeout after {timeout} cycles")
            continue
        
        # Read result
        result_packed = int(dut.result_word.value)
        result_bytes = [(result_packed >> (i * 8)) & 0xFF for i in range(8)]
        result_str = ''.join(chr(b) if b != 0 else '' for b in result_bytes)
        # Remove trailing nulls
        result_str = result_str.rstrip('\x00')
        
        print(f"  Got: '{result_str}' (took {cycles} cycles)")
        
        if result_str == expected:
            print("  PASSED")
            passed += 1
        else:
            print(f"  FAILED: Expected '{expected}', got '{result_str}'")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases: single character words, equal counts"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        setattr(dut, f"word{i}", 0)
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case 1: All same unique count, pick first lexicographically
    # "abc" (3 unique), "def" (3 unique) -> "abc"
    print("
Edge case 1: Tie-breaking (abc vs def)")
    words = ["def", "abc", "ghi", "", "", "", "", ""]
    for i, w in enumerate(words):
        byte_array = str_to_bytes(w)
        packed = 0
        for j, b in enumerate(byte_array):
            packed |= (b << (j * 8))
        setattr(dut, f"word{i}", packed)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 600
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    result_packed = int(dut.result_word.value)
    result_bytes = [(result_packed >> (i * 8)) & 0xFF for i in range(8)]
    result_str = ''.join(chr(b) if b != 0 else '' for b in result_bytes).rstrip('\x00')
    print(f"  Result: '{result_str}', Expected: 'abc'")
    assert result_str == "abc", "Tie-breaking failed"
    
    # Edge case 2: All empty strings
    print("
Edge case 2: All empty strings")
    for i in range(8):
        setattr(dut, f"word{i}", 0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    result_packed = int(dut.result_word.value)
    result_bytes = [(result_packed >> (i * 8)) & 0xFF for i in range(8)]
    result_str = ''.join(chr(b) if b != 0 else '' for b in result_bytes).rstrip('\x00')
    print(f"  Result: '{result_str}' (empty)")
    assert result_str == "", "All empty case failed"
    
    # Edge case 3: Maximum unique chars in last position
    print("
Edge case 3: Max unique at last index")
    words = ["a", "aa", "aaa", "aaaa", "aaaaa", "aaaaaa", "aaaaaaa", "abcdefgh"]
    for i, w in enumerate(words):
        byte_array = str_to_bytes(w)
        packed = 0
        for j, b in enumerate(byte_array):
            packed |= (b << (j * 8))
        setattr(dut, f"word{i}", packed)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    result_packed = int(dut.result_word.value)
    result_bytes = [(result_packed >> (i * 8)) & 0xFF for i in range(8)]
    result_str = ''.join(chr(b) if b != 0 else '' for b in result_bytes).rstrip('\x00')
    expected = "abcdefgh"
    print(f"  Result: '{result_str}', Expected: '{expected}'")
    assert result_str == expected, "Last index case failed"
    
    print("
All edge cases passed")
