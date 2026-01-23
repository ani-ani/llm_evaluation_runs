import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_vowels_count(dut):
    """Test the vowels_count module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_len.value = 0
    for i in range(8):
        setattr(dut, f'char_{i}').value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test helper function
    async def run_test(input_str, expected):
        dut._log.info(f"Testing: '{input_str}' -> Expected: {expected}")
        
        # Set input characters
        valid_len = len(input_str)
        dut.valid_len.value = valid_len
        
        for i in range(8):
            if i < valid_len:
                setattr(dut, f'char_{i}').value = ord(input_str[i])
            else:
                setattr(dut, f'char_{i}').value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        count = 0
        while not dut.done.value and count < timeout:
            await RisingEdge(dut.clk)
            count += 1
        
        # Check result
        actual = int(dut.result.value)
        assert actual == expected, f"Failed: got {actual}, expected {expected}"
        
        await Timer(10, units='ns')
    
    # Run test cases from original problem
    await run_test("abcde", 2)
    await run_test("Alone", 3)
    await run_test("key", 2)
    await run_test("bye", 1)
    await run_test("keY", 2)
    await run_test("bYe", 1)
    await run_test("ACEDY", 3)
    
    # Additional edge cases
    await run_test("aaaaa", 5)  # All vowels
    await run_test("bcdfg", 0)  # No vowels
    await run_test("y", 1)       # Single 'y' at end
    await run_test("Y", 1)       # Single 'Y' at end
    await run_test("yabc", 1)    # 'y' at start (not counted)
    await run_test("abcY", 2)    # 'Y' at end (counted)
    await run_test("aeiou", 5)   # All vowels
    await run_test("AEIOU", 5)   # All uppercase vowels
    await run_test("", 0)        # Empty string (valid_len=0)
    await run_test("yy", 2)      # Two 'y's, last is counted
    await run_test("yY", 2)      # Two 'y's, last is counted
    await run_test("tEst", 1)    # Mixed case
    await run_test("quiZ", 2)    # i and z (z not vowel)
    
    dut._log.info("All tests passed!")
