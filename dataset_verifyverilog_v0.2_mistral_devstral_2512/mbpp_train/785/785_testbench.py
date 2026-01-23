import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_tuple_parser(dut):
    """Test tuple string to integer tuple conversion"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.tuple_str.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert string to 64-bit value
    def str_to_bits(s, width=8):
        padded = s.ljust(width, ' ')
        result = 0
        for i, ch in enumerate(padded):
            result |= (ord(ch) << ((width-1-i)*8))
        return result
    
    # Helper function to verify results
    async def parse_and_check(input_str, expected):
        dut._log.info(f"Testing: {input_str}")
        
        # Set input
        dut.tuple_str.value = str_to_bits(input_str, width=8)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check error flag
        if dut.error.value == 1:
            dut._log.error(f"Error flag set for input: {input_str}")
            assert False, f"Error flag set for valid input: {input_str}"
        
        # Check result
        if dut.done.value == 1:
            actual = []
            for i in range(3):
                actual.append(int(dut.result[i].value))
            
            dut._log.info(f"Expected: {expected}, Got: {actual}")
            assert actual == list(expected), f"Mismatch for {input_str}: expected {expected}, got {actual}"
        else:
            assert False, "Done signal not asserted within timeout"
    
    # Test case 1: "(7, 8, 9)" -> (7, 8, 9)
    await parse_and_check("(7,8,9)", (7, 8, 9))
    await RisingEdge(dut.clk)
    
    # Test case 2: "(1, 2, 3)" -> (1, 2, 3)
    await parse_and_check("(1,2,3)", (1, 2, 3))
    await RisingEdge(dut.clk)
    
    # Test case 3: "(4, 5, 6)" -> (4, 5, 6)
    await parse_and_check("(4,5,6)", (4, 5, 6))
    await RisingEdge(dut.clk)
    
    # Test case 4: "(7, 81, 19)" -> (7, 81, 19) (two-digit numbers)
    await parse_and_check("(7,81,19)", (7, 81, 19))
    await RisingEdge(dut.clk)
    
    # Additional edge cases
    # Test 5: "(10,20,30)" -> (10, 20, 30)
    await parse_and_check("(10,20,30)", (10, 20, 30))
    await RisingEdge(dut.clk)
    
    # Test 6: "(99,0,5)" -> (99, 0, 5) (max and min values)
    await parse_and_check("(99,0,5)", (99, 0, 5))
    await RisingEdge(dut.clk)
    
    dut._log.info("All 6 tests passed!")
