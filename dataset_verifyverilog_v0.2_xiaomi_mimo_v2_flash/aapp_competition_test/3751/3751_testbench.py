import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_identifier_validator(dut):
    """Test the identifier validator module"""
    
    # Create a clock with a 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    
    # Reset sequence
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def send_string(s):
        """Helper to send a string character by character"""
        # Start signal
        dut.start.value = 1
        dut.valid_in.value = 1
        
        for i, char in enumerate(s):
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
            dut.start.value = 0  # Start only for first char
            
            # Check result after cycle
            if i > 0:
                # Just process, checking happens at end
                pass
                
        # Send invalid to terminate/end stream
        dut.valid_in.value = 0
        dut.char_in.value = 0
        await RisingEdge(dut.clk)
        
    # Test Case 1: Valid "abacaba"
    dut._log.info("Test 1: abacaba (Valid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Manually step through for precise checking
    dut.start.value = 1
    dut.valid_in.value = 1
    
    # a - first char, must be 'a'
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    if dut.error.value == 1:
        raise TestFailure("Error on 'a' first char")
    
    # b - new, expects 'b' (ok)
    dut.char_in.value = ord('b')
    await RisingEdge(dut.clk)
    if dut.error.value == 1:
        raise TestFailure("Error on 'b' expected")
    
    # a - duplicate (ok)
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    if dut.error.value == 1:
        raise TestFailure("Error on duplicate 'a'")
    
    # c - new, expects 'c' (ok)
    dut.char_in.value = ord('c')
    await RisingEdge(dut.clk)
    if dut.error.value == 1:
        raise TestFailure("Error on 'c' expected")
    
    # a - duplicate (ok)
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    if dut.error.value == 1:
        raise TestFailure("Error on duplicate 'a'")
    
    # b - duplicate (ok)
    dut.char_in.value = ord('b')
    await RisingEdge(dut.clk)
    if dut.error.value == 1:
        raise TestFailure("Error on duplicate 'b'")
    
    # a - duplicate (ok)
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    if dut.error.value == 1:
        raise TestFailure("Error on duplicate 'a'")
    
    # End stream
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    if dut.result.value != 1:
        raise TestFailure("Result should be 1 for valid string")
    
    # Test Case 2: "jinotega" (Invalid, starts with 'j')
    dut._log.info("Test 2: jinotega (Invalid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.valid_in.value = 1
    
    # j - first char, must be 'a' -> Error
    dut.char_in.value = ord('j')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    if dut.error.value != 1:
        raise TestFailure("Should error on 'j' as first char")
    
    # Continue sending rest (module should stay in error)
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test Case 3: "aba" (Valid)
    dut._log.info("Test 3: aba (Valid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.valid_in.value = 1
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.char_in.value = ord('b')
    await RisingEdge(dut.clk)
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    if dut.result.value != 1:
        raise TestFailure("Result should be 1 for 'aba'")
        
    # Test Case 4: "bab" (Invalid)
    dut._log.info("Test 4: bab (Invalid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.valid_in.value = 1
    
    # b - first char, must be 'a' -> Error
    dut.char_in.value = ord('b')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    if dut.error.value != 1:
        raise TestFailure("Should error on 'b' as first char")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test Case 5: "a" (Valid)
    dut._log.info("Test 5: a (Valid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.valid_in.value = 1
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    if dut.result.value != 1:
        raise TestFailure("Result should be 1 for 'a'")
    
    # Test Case 6: "abc" (Valid)
    dut._log.info("Test 6: abc (Valid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.valid_in.value = 1
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.char_in.value = ord('b')
    await RisingEdge(dut.clk)
    
    dut.char_in.value = ord('c')
    await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    if dut.result.value != 1:
        raise TestFailure("Result should be 1 for 'abc'")
    
    # Test Case 7: "acb" (Invalid)
    dut._log.info("Test 7: acb (Invalid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.valid_in.value = 1
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.char_in.value = ord('c')
    await RisingEdge(dut.clk)
    if dut.error.value != 1:
        raise TestFailure("Should error on 'c' after 'a' (expected 'b')")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test Case 8: "abba" (Valid)
    dut._log.info("Test 8: abba (Valid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.valid_in.value = 1
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.char_in.value = ord('b')
    await RisingEdge(dut.clk)
    
    dut.char_in.value = ord('b')
    await RisingEdge(dut.clk)
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    if dut.result.value != 1:
        raise TestFailure("Result should be 1 for 'abba'")
    
    # Test Case 9: "aaac" (Invalid, skips b)
    dut._log.info("Test 9: aaac (Invalid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.valid_in.value = 1
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    
    dut.char_in.value = ord('a')
    await RisingEdge(dut.clk)
    
    dut.char_in.value = ord('c')
    await RisingEdge(dut.clk)
    if dut.error.value != 1:
        raise TestFailure("Should error on 'c' (expected 'b')")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test Case 10: "abcdefghijklmnopqrstuvwxyz" (Valid)
    dut._log.info("Test 10: abcdefghijklmnopqrstuvwxyz (Valid)")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    dut.valid_in.value = 1
    
    for i in range(26):
        dut.char_in.value = ord('a') + i
        await RisingEdge(dut.clk)
        dut.start.value = 0
        if dut.error.value == 1:
            raise TestFailure(f"Error on char {chr(ord('a')+i)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    if dut.result.value != 1:
        raise TestFailure("Result should be 1 for full alphabet")
    
    dut._log.info("All tests passed!")
