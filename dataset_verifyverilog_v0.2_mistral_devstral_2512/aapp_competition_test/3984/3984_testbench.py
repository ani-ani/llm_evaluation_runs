import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_game_winner(dut):
    """Test Mike and Ann game winner determination"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: "abba" -> Mike, Ann, Ann, Mike
    test_strings = [
        "abba",
        "cba",
        "a",
        "zzzz",
        "aaab"
    ]
    
    expected_results = [
        [0, 1, 1, 0],  # abba: Mike, Ann, Ann, Mike
        [0, 0, 0],     # cba: Mike, Mike, Mike
        [0],           # a: Mike
        [0, 0, 0, 0],  # zzzz: Mike, Mike, Mike, Mike
        [0, 0, 0, 1]   # aaab: Mike, Mike, Mike, Ann
    ]
    
    total_tests = 0
    passed_tests = 0
    
    for test_idx, test_str in enumerate(test_strings):
        expected = expected_results[test_idx]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Process each character
        min_char = 127  # ASCII max
        results = []
        
        for i, char in enumerate(test_str):
            # Feed character
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)  # Wait for pipeline
            
            # Check valid flag
            if dut.valid.value == 1:
                actual = int(dut.result.value)
                results.append(actual)
            else:
                results.append(-1)  # Invalid
            
            # Update min for verification
            min_char = min(min_char, ord(char))
            
            total_tests += 1
        
        # Wait for done
        for _ in range(5):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify results
        for i, (actual, expect) in enumerate(zip(results, expected)):
            if actual == expect:
                passed_tests += 1
            else:
                raise TestFailure(f"Test {test_idx+1}, char {i}: Expected {expect}, got {actual}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    print(f"
Test Summary: {passed_tests}/{total_tests} tests passed")
    assert passed_tests == total_tests, f"Only {passed_tests}/{total_tests} tests passed"
