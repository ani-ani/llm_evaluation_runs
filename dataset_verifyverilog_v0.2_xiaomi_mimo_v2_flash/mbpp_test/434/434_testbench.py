import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_regex_matcher(dut):
    """Test regex pattern matcher for 'ab+' on fixed-width strings"""
    
    # Create clock
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
    
    # Test helper function
    async def test_string(test_str, expected_match):
        """Test a single string against the pattern"""
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed 8 characters (pad with nulls)
        for i in range(8):
            if i < len(test_str):
                dut.char_in.value = ord(test_str[i])
            else:
                dut.char_in.value = 0
            dut.char_index.value = i
            await RisingEdge(dut.clk)
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        result = bool(dut.match_result.value)
        return result
    
    # Test cases
    tests = [
        ("ac", False),      # Test 1: 'a' but no 'b' after
        ("dc", False),      # Test 2: no 'a' at all
        ("abba", True),     # Test 3: 'a' followed by 'b's
        ("ab", True),       # Additional: minimal pattern
        ("a", False),       # Edge: just 'a', no 'b'
        ("b", False),       # Edge: just 'b', no 'a'
        ("abab", True),     # Multiple patterns (first one matches)
        ("xaby", True),     # Pattern in middle
        ("aaa", False),     # 'a's but no 'b' after
        ("bbbb", False),    # 'b's but no 'a' before
        ("", False),        # Empty string
        ("abb", True),      # Test multiple b's
    ]
    
    passed = 0
    total = len(tests)
    
    for test_str, expected in tests:
        result = await test_string(test_str, expected)
        if result == expected:
            passed += 1
            print(f"PASS: '{test_str}' -> {result} (expected {expected})")
        else:
            print(f"FAIL: '{test_str}' -> {result} (expected {expected})")
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Expected {total} tests, but {passed} passed"
