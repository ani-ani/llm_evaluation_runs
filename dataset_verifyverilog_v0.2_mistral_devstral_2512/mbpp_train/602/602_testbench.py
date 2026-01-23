import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_first_repeated_char(dut):
    """Test first repeated character detection"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_count.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to run a test case
    async def run_test(input_string, expected_char):
        dut._log.info(f"Testing with string: '{input_string}' (expected: {expected_char})")
        
        # Convert string to ASCII bytes
        char_list = [ord(c) for c in input_string]
        num_chars = len(char_list)
        
        # Set start signal
        dut.start.value = 1
        dut.char_count.value = num_chars
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters in READING state
        for i, ascii_val in enumerate(char_list):
            dut.char_in.value = ascii_val
            await RisingEdge(dut.clk)
        
        # Wait for processing (max 8 cycles) and check done
        max_cycles = 8
        for _ in range(max_cycles):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.result.value
        expected = ord(expected_char) if expected_char else 0
        
        if actual != expected:
            raise TestFailure(f"Expected {expected} ({expected_char if expected_char else 'None'}), got {actual}")
        
        dut._log.info(f"Test passed: got {actual}")
        
        # Reset for next test
        dut.start.value = 0
        dut.char_in.value = 0
        dut.char_count.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Test 1: "abcabc" -> 'a'
    await run_test("abcabc", "a")
    
    # Test 2: "abc" -> None (0x00)
    await run_test("abc", None)
    
    # Test 3: "123123" -> '1'
    await run_test("123123", "1")
    
    # Additional edge case: "aabb" -> 'a' (second 'a' comes before second 'b')
    await run_test("aabb", "a")
    
    # Additional edge case: "abca" -> 'a' ('a' repeats before 'a' appears again)
    await run_test("abca", "a")
    
    dut._log.info("All tests passed!")
