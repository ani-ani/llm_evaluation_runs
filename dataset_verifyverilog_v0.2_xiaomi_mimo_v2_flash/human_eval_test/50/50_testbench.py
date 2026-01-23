import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def encode_shift(s: str):
    return "".join([chr(((ord(ch) + 5 - ord("a")) % 26) + ord("a")) for ch in s])

def decode_shift(s: str):
    result = []
    for ch in s:
        if 'a' <= ch <= 'z':
            decoded = chr(((ord(ch) - 5 - ord("a")) % 26) + ord("a"))
            result.append(decoded)
        else:
            result.append(ch)
    return "".join(result)

@cocotb.test()
async def test_caesar_decode(dut):
    """Test Caesar cipher decoder with shift value of 5"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    dut.char_done.value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_strings = [
        "hello",
        "zebra",
        "abcxyz",
        "python",
        "cipher",
        "aaaaa",
        "zzzzz",
        "a!b@",
        "test123",
        ""
    ]
    
    tests_passed = 0
    tests_total = len(test_strings)
    
    for test_str in test_strings:
        dut._log.info(f"Testing string: '{test_str}'")
        
        # Encode first
        encoded = encode_shift(test_str)
        dut._log.info(f"Encoded: '{encoded}'")
        
        # Start decoding
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Stream characters
        decoded_result = []
        for i, ch in enumerate(encoded):
            dut.char_in.value = ord(ch)
            dut.char_valid.value = 1
            if i == len(encoded) - 1:
                dut.char_done.value = 1
            
            await RisingEdge(dut.clk)
            
            # Read output from previous cycle
            if dut.char_out_valid.value:
                decoded_result.append(chr(int(dut.char_out.value)))
            
            dut.char_valid.value = 0
            dut.char_done.value = 0
        
        # Wait for final output
        await RisingEdge(dut.clk)
        if dut.char_out_valid.value:
            decoded_result.append(chr(int(dut.char_out.value)))
        
        # Wait for done
        timeout = 10
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        decoded_str = "".join(decoded_result)
        dut._log.info(f"Decoded: '{decoded_str}'")
        
        # Verify
        if decoded_str == test_str:
            tests_passed += 1
            dut._log.info(f"PASS: '{test_str}'")
        else:
            dut._log.error(f"FAIL: Expected '{test_str}', got '{decoded_str}'")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Additional edge cases with special characters
    dut._log.info("
=== Edge Cases ===")
    
    # Test single character
    for single_char in ['a', 'z', 'm', '!']:
        encoded = encode_shift(single_char) if single_char.isalpha() else single_char
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        dut.char_in.value = ord(encoded)
        dut.char_valid.value = 1
        dut.char_done.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        dut.char_done.value = 0
        
        await RisingEdge(dut.clk)
        result = chr(int(dut.char_out.value))
        expected = single_char
        
        if result == expected:
            tests_passed += 1
            dut._log.info(f"PASS: Single char '{single_char}'")
        else:
            dut._log.error(f"FAIL: Single char '{single_char}' expected '{expected}', got '{result}'")
        
        tests_total += 1
        await RisingEdge(dut.clk)
    
    # Test boundary: all lowercase a-z
    all_chars = "abcdefghijklmnopqrstuvwxyz"
    encoded_all = encode_shift(all_chars)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    decoded_all = []
    for i, ch in enumerate(encoded_all):
        dut.char_in.value = ord(ch)
        dut.char_valid.value = 1
        if i == len(encoded_all) - 1:
            dut.char_done.value = 1
        
        await RisingEdge(dut.clk)
        
        if dut.char_out_valid.value:
            decoded_all.append(chr(int(dut.char_out.value)))
        
        dut.char_valid.value = 0
        dut.char_done.value = 0
    
    await RisingEdge(dut.clk)
    if dut.char_out_valid.value:
        decoded_all.append(chr(int(dut.char_out.value)))
    
    decoded_all_str = "".join(decoded_all)
    if decoded_all_str == all_chars:
        tests_passed += 1
        dut._log.info("PASS: All lowercase letters")
    else:
        dut._log.error(f"FAIL: All lowercase letters expected '{all_chars}', got '{decoded_all_str}'")
    tests_total += 1
    
    dut._log.info(f"
=== SUMMARY: {tests_passed}/{tests_total} tests passed ===")
    
    if tests_passed != tests_total:
        raise TestFailure(f"Only {tests_passed}/{tests_total} tests passed")
