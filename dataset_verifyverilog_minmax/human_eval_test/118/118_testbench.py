import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_closest_vowel(dut):
    # ASCII helper functions
    def char(c): return ord(c)
    vowels = "AEIOUaeiou"
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (input_word, expected_output)
    test_cases = [
        ("yogurt", "u"),
        ("full", "u"),
        ("easy", ""),
        ("eAsy", ""),
        ("ali", ""),
        ("bad", "a"),
        ("most", "o"),
        ("quick", ""),
        ("anime", "i"),
        ("Asia", ""),
        ("Above", "o")
    ]
    
    passed = 0
    total = len(test_cases)
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for word, expected_str in test_cases:
        expected = ord(expected_str) if expected_str else 0
        
        # Prepare word input
        length = len(word)
        padded_word = word.ljust(16, '\\0')
        for i in range(16):
            dut.word[i].value = ord(padded_word[i])
        dut.length.value = length
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: '{word}' -> '{expected_str}'")
        else:
            actual = chr(dut.result.value) if dut.result.value !=0 else ''
            dut._log.error(f"FAIL: '{word}' returned '{actual}', expected '{expected_str}'")
        
        # Wait a cycle between tests
        await RisingEdge(dut.clk)
    
    # Special edge cases
    # Test 1: Empty string
    for i in range(16):
        dut.word[i].value = 0
    dut.length.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    if dut.result.value == 0:
        passed += 1
        dut._log.info("PASS: edge case empty string")
    else:
        dut._log.error(f"FAIL: empty string returned {dut.result.value}")
    total += 1
    
    # Test 2: Max length string
    long_word = 'aBcDeFgHiJkLmNoP'  # No valid vowels
    for i in range(16):
        dut.word[i].value = ord(long_word[i])
    dut.length.value = 16
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    if dut.result.value == 0:
        passed += 1
        dut._log.info("PASS: edge case max length")
    else:
        dut._log.error(f"FAIL: max length returned {dut.result.value}")
    total += 1
    
    dut._log.info(f"{passed}/{total} tests passed")