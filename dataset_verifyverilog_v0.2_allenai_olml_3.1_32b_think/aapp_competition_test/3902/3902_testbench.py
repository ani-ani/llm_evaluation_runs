import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure, TestSuccess
import random

# Helper function to encode a string to 5-bit per char representation
def encode_string(s):
    encoded = 0
    for char in s:
        encoded = (encoded << 5) | (ord(char) - ord('a'))
    return encoded

def decode_value(val, length):
    chars = []
    for _ in range(length):
        char_code = val & 0x1F
        chars.append(chr(char_code + ord('a')))
        val >>= 5
    return ''.join(reversed(chars))

@cocotb.test()
async def test_reberland_suffix(dut):
    """Test the Reberland Suffix module"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.len_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: abacabaca (Expected: aca, ba, ca)
    s1 = "abacabaca"
    dut.len_in.value = len(s1)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load characters
    for char in s1:
        dut.char_in.value = ord(char) - ord('a')
        await RisingEdge(dut.clk)
    
    # Collect outputs
    found_suffixes = set()
       timeout = 0
    while timeout < 200:
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            length = int(dut.suffix_len.value)
            val = int(dut.suffix_out.value)
            decoded = decode_value(val, length)
            found_suffixes.add(decoded)
            print(f"Found suffix: {decoded}")
        if dut.done.value == 1:
            break
        timeout += 1
    
    expected1 = {'aca', 'ba', 'ca'}
    if found_suffixes != expected1:
        raise TestFailure(f"Test 1 Failed: Expected {expected1}, got {found_suffixes}")
    print("Test 1 Passed")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: abaca (Expected: 0)
    s2 = "abaca"
    dut.len_in.value = len(s2)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in s2:
        dut.char_in.value = ord(char) - ord('a')
        await RisingEdge(dut.clk)
    
    found_suffixes = set()
    timeout = 0
    while timeout < 200:
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            length = int(dut.suffix_len.value)
            val = int(dut.suffix_out.value)
            decoded = decode_value(val, length)
            found_suffixes.add(decoded)
        if dut.done.value == 1:
            break
        timeout += 1
        
    if found_suffixes:
        raise TestFailure(f"Test 2 Failed: Expected empty set, got {found_suffixes}")
    print("Test 2 Passed")
    
    # Test Case 3: xxxxxy (Expected: xy, yy)
    s3 = "xxxxxy"
    dut.len_in.value = len(s3)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in s3:
        dut.char_in.value = ord(char) - ord('a')
        await RisingEdge(dut.clk)
    
    found_suffixes = set()
    timeout = 0
    while timeout < 200:
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            length = int(dut.suffix_len.value)
            val = int(dut.suffix_out.value)
            decoded = decode_value(val, length)
            found_suffixes.add(decoded)
        if dut.done.value == 1:
            break
        timeout += 1

    expected3 = {'xy', 'yy'}
    if found_suffixes != expected3:
        raise TestFailure(f"Test 3 Failed: Expected {expected3}, got {found_suffixes}")
    print("Test 3 Passed")
    
    print(f"Summary: {3}/{3} tests passed")
