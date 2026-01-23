import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_goldbach_checker(dut):
    """Test the Goldbach checker module with various inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.char_valid.value = 0
    dut.char_last.value = 0
    dut.char_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def feed_string(input_str):
        """Helper to feed a string character by character"""
        dut.char_valid.value = 1
        for i, char in enumerate(input_str):
            dut.char_in.value = ord(char)
            dut.char_last.value = 1 if i == len(input_str) - 1 else 0
            await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        
        # Wait for processing to complete
        for _ in range(300):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        return int(dut.result.value)
    
    # Test Case 1: Valid "10 3 7" (10=3+7, 3 and 7 are prime)
    dut._log.info("Test 1: Valid '10 3 7'")
    result = await feed_string("10 3 7")
    if result != 1:
        raise TestFailure(f"Test 1 failed: expected 1, got {result}")
    
    # Test Case 2: Valid with extra whitespace "10   3   7"
    dut._log.info("Test 2: Valid '10   3   7'")
    result = await feed_string("10   3   7")
    if result != 1:
        raise TestFailure(f"Test 2 failed: expected 1, got {result}")
    
    # Test Case 3: Invalid "314
159 265
358" (multiple lines, wrong token count)
    dut._log.info("Test 3: Invalid '314
159 265
358'")
    result = await feed_string("314
159 265
358")
    if result != 0:
        raise TestFailure(f"Test 3 failed: expected 0, got {result}")
    
    # Test Case 4: Valid "22 19 3" (22=19+3)
    dut._log.info("Test 4: Valid '22 19 3'")
    result = await feed_string("22 19 3")
    if result != 1:
        raise TestFailure(f"Test 4 failed: expected 1, got {result}")
    
    # Test Case 5: Valid with lots of whitespace and newlines
    dut._log.info("Test 5: Valid with whitespace/newlines")
    result = await feed_string("

   60
  
  29
  
      31
")
    if result != 1:
        raise TestFailure(f"Test 5 failed: expected 1, got {result}")
    
    # Test Case 6: Invalid with text "fred!
sam!
george!"
    dut._log.info("Test 6: Invalid text 'fred!
sam!
george!'")
    result = await feed_string("fred!
sam!
george!")
    if result != 0:
        raise TestFailure(f"Test 6 failed: expected 0, got {result}")
    
    # Additional edge cases
    # Test 7: Leading zero invalid "010 3 7"
    dut._log.info("Test 7: Invalid leading zero '010 3 7'")
    result = await feed_string("010 3 7")
    if result != 0:
        raise TestFailure(f"Test 7 failed: expected 0, got {result}")
    
    # Test 8: Non-prime summands "10 4 6"
    dut._log.info("Test 8: Invalid non-prime '10 4 6'")
    result = await feed_string("10 4 6")
    if result != 0:
        raise TestFailure(f"Test 8 failed: expected 0, got {result}")
    
    # Test 9: Sum mismatch "10 5 5" (10=5+5 but only 1 prime check needed)
    dut._log.info("Test 9: Sum mismatch '10 5 5'")
    result = await feed_string("10 5 5")
    if result != 1:
        raise TestFailure(f"Test 9 failed: expected 1, got {result}")
    
    # Test 10: Odd first number "11 2 2" (invalid, must be even)
    dut._log.info("Test 10: Invalid odd first '11 2 2'")
    result = await feed_string("11 2 2")
    if result != 0:
        raise TestFailure(f"Test 10 failed: expected 0, got {result}")
    
    # Test 11: Too many tokens "10 3 7 11"
    dut._log.info("Test 11: Too many tokens '10 3 7 11'")
    result = await feed_string("10 3 7 11")
    if result != 0:
        raise TestFailure(f"Test 11 failed: expected 0, got {result}")
    
    # Test 12: First number too large (scaled to >50000) "50002 25001 25001" - 25001 is odd, not prime
    dut._log.info("Test 12: Large even with non-prime '50002 25001 25001'")
    result = await feed_string("50002 25001 25001")
    if result != 0:
        raise TestFailure(f"Test 12 failed: expected 0, got {result}")
    
    # Test 13: Valid larger example "100 3 97" (both primes, sum 100)
    dut._log.info("Test 13: Valid '100 3 97'")
    result = await feed_string("100 3 97")
    if result != 1:
        raise TestFailure(f"Test 13 failed: expected 1, got {result}")
    
    dut._log.info("All tests completed!")
