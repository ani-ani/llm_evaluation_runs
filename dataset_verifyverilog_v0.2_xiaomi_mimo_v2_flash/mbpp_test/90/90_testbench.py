import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_longest_word_length(dut):
    """Test the longest word length finder"""
    
    # Helper function to convert string to fixed-width byte array
    def str_to_bytes(s, width=8):
        bytes_out = []
        for i in range(width):
            if i < len(s):
                bytes_out.append(ord(s[i]))
            else:
                bytes_out.append(0)  # NULL terminator
        return bytes_out
    
    # Helper function to set all characters
    def set_chars(dut, words):
        # words is list of up to 8 strings, each max 8 chars
        idx = 0
        for word_idx, word in enumerate(words):
            byte_array = str_to_bytes(word, width=8)
            for char_idx, byte_val in enumerate(byte_array):
                setattr(dut, f'char_{idx}', byte_val)
                idx += 1
        # Fill remaining with zeros (NULL)
        for i in range(idx, 64):
            setattr(dut, f'char_{i}', 0)
    
    # Test 1: ["python","PHP","bigdata"]
    # python = 6 chars, PHP = 3 chars, bigdata = 7 chars -> max = 7
    dut._log.info("Test 1: ['python','PHP','bigdata']")
    set_chars(dut, ["python", "PHP", "bigdata"])
    await Timer(10, units='ns')
    assert dut.max_length.value == 7, f"Expected 7, got {dut.max_length.value}"
    
    # Test 2: ["a","ab","abc"]
    # a = 1 char, ab = 2 chars, abc = 3 chars -> max = 3
    dut._log.info("Test 2: ['a','ab','abc']")
    set_chars(dut, ["a", "ab", "abc"])
    await Timer(10, units='ns')
    assert dut.max_length.value == 3, f"Expected 3, got {dut.max_length.value}"
    
    # Test 3: ["small","big","tall"]
    # small = 5 chars, big = 3 chars, tall = 5 chars -> max = 5
    dut._log.info("Test 3: ['small','big','tall']")
    set_chars(dut, ["small", "big", "tall"])
    await Timer(10, units='ns')
    assert dut.max_length.value == 5, f"Expected 5, got {dut.max_length.value}"
    
    # Test 4: All same length
    dut._log.info("Test 4: ['cat','dog','rat'] all 3 chars")
    set_chars(dut, ["cat", "dog", "rat"])
    await Timer(10, units='ns')
    assert dut.max_length.value == 3, f"Expected 3, got {dut.max_length.value}"
    
    # Test 5: Single character words
    dut._log.info("Test 5: ['x','y','z']")
    set_chars(dut, ["x", "y", "z"])
    await Timer(10, units='ns')
    assert dut.max_length.value == 1, f"Expected 1, got {dut.max_length.value}"
    
    # Test 6: Maximum length word
    dut._log.info("Test 6: ['abcdefgh','a','b']")
    set_chars(dut, ["abcdefgh", "a", "b"])
    await Timer(10, units='ns')
    assert dut.max_length.value == 8, f"Expected 8, got {dut.max_length.value}"
    
    # Test 7: Empty string (all NULL) should be length 0
    dut._log.info("Test 7: ['','','']")
    set_chars(dut, ["", "", ""])
    await Timer(10, units='ns')
    assert dut.max_length.value == 0, f"Expected 0, got {dut.max_length.value}"
    
    # Test 8: Mixed with empty
    dut._log.info("Test 8: ['','abc','']")
    set_chars(dut, ["", "abc", ""])
    await Timer(10, units='ns')
    assert dut.max_length.value == 3, f"Expected 3, got {dut.max_length.value}"
    
    dut._log.info(f"All 8 tests passed!")