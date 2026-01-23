import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_word_len_checker(dut):
    """Test word_len_checker module with various inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    dut.char_last.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to process a string
    async def process_string(s, expected):
        dut._log.info(f"Testing: '{s}' expecting result={expected}")
        
        # Reset result and done
        dut.result.value = 0
        dut.done.value = 0
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send characters
        for i, char in enumerate(s):
            dut.char_in.value = ord(char)
            dut.char_valid.value = 1
            dut.char_last.value = (i == len(s) - 1)
            await RisingEdge(dut.clk)
        
        # Wait for done
        timeout = 20
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Done not asserted after {timeout} cycles")
        
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Expected {expected}, got {actual} for string '{s}'")
        
        dut._log.info(f"  Result: {actual} - PASS")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    # Test cases from problem
    await process_string("Hadoop", 0)  # length 6, even
    await process_string("great", 1)   # length 5, odd
    await process_string("structure", 1)  # length 9, odd
    
    # Additional edge cases
    await process_string("a", 1)  # single odd-length word
    await process_string("ab", 0)  # single even-length word
    await process_string("hi bye", 0)  # two even words
    await process_string("a b", 1)  # two odd words
    await process_string("ok now", 1)  # second word odd
    await process_string("cat dog mouse", 0)  # all odd lengths: 3,3,5 -> all odd, result=1
    
    dut._log.info("All tests passed!")
