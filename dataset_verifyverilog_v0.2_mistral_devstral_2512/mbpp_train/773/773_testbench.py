import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

def str_to_bytes(s):
    """Convert string to list of byte values, padded to 16 chars"""
    bytes_list = [ord(c) for c in s]
    return bytes_list + [0] * (16 - len(bytes_list))

def pattern_to_bytes(s):
    """Convert pattern to list of byte values, padded to 8 chars"""
    bytes_list = [ord(c) for c in s]
    return bytes_list + [0] * (8 - len(bytes_list))

def expected_result(text, pattern):
    """Calculate expected match position"""
    if len(pattern) == 0 or len(text) < len(pattern):
        return None
    
    for i in range(len(text) - len(pattern) + 1):
        if text[i:i+len(pattern)] == pattern:
            return (i, i + len(pattern))
    return None

@cocotb.test()
async def test_substring_matcher(dut):
    """Test substring matcher module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.text_len.value = 0
    dut.pattern_len.value = 0
    for i in range(16):
        dut.text[i].value = 0
    for i in range(8):
        dut.pattern[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (text, pattern, expected_start, expected_end, match_found, description)
        ('python programming, python language', 'python', 0, 6, True, 'Test 1: First python at position 0'),
        ('python programming,programming language', 'programming', 7, 18, True, 'Test 2: programming at 7'),
        ('python programming,programming language', 'language', 31, 39, True, 'Test 3: language at 31'),
        ('c++ programming, c++ language', 'python', 0, 0, False, 'Test 4: No match'),
        ('hello', 'hello', 0, 5, True, 'Test 5: Full string match'),
        ('a', 'a', 0, 1, True, 'Test 6: Single character match'),
        ('ab', 'abc', 0, 0, False, 'Test 7: Pattern longer than text'),
        ('', 'test', 0, 0, False, 'Test 8: Empty text'),
        ('test', '', 0, 0, False, 'Test 9: Empty pattern'),
        ('xxxxxx', 'x', 0, 1, True, 'Test 10: First of many'),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (text_str, pattern_str, exp_start, exp_end, exp_match, desc) in enumerate(test_cases):
        dut._log.info(f"Running test {i+1}: {desc}")
        
        # Load inputs
        text_bytes = str_to_bytes(text_str)
        pattern_bytes = pattern_to_bytes(pattern_str)
        
        for j in range(16):
            dut.text[j].value = text_bytes[j]
        for j in range(8):
            dut.pattern[j].value = pattern_bytes[j]
        
        dut.text_len.value = len(text_str)
        dut.pattern_len.value = len(pattern_str)
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 300 cycles to be safe)
        timeout = 300
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Check results
        if exp_match:
            if not dut.match_found.value:
                raise TestFailure(f"Test {i+1}: Expected match but got none. {desc}")
            if dut.start_pos.value != exp_start:
                raise TestFailure(f"Test {i+1}: Wrong start pos. Expected {exp_start}, got {dut.start_pos.value}")
            if dut.end_pos.value != exp_end:
                raise TestFailure(f"Test {i+1}: Wrong end pos. Expected {exp_end}, got {dut.end_pos.value}")
        else:
            if dut.match_found.value:
                raise TestFailure(f"Test {i+1}: Expected no match but found one at {dut.start_pos.value}")
        
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Not all tests passed: {passed}/{total}"
