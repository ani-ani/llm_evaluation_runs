import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_select_words(dut):
    """Test select_words module with various strings and n values"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.char_in.value = 0x20
    dut.char_index.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to run a test
    async def run_test(test_string, target_n, expected_words):
        dut._log.info(f"Testing: '{test_string}' with n={target_n}")
        
        # Pad string to 16 characters with spaces
        padded = test_string.ljust(16, ' ')
        
        # Start
        dut.n.value = target_n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters one by one with valid pulse
        for i, char in enumerate(padded):
            dut.char_in.value = ord(char)
            dut.char_index.value = i
            dut.valid.value = 1
            await RisingEdge(dut.clk)
            dut.valid.value = 0
            await RisingEdge(dut.clk)
        
        # Wait for completion (max 20 extra cycles)
        for _ in range(25):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        # Check results
        if not dut.done.value:
            raise TestFailure(f"Module did not complete in time")
        
        word_count = int(dut.word_count.value)
        dut._log.info(f"Found {word_count} words")
        
        if word_count != len(expected_words):
            raise TestFailure(f"Expected {len(expected_words)} words, got {word_count}")
        
        # Check each word
        for i, expected in enumerate(expected_words):
            # Read word from output array
            actual_chars = []
            for j in range(8):
                char_val = int(dut.words[i][j].value)
                if char_val != 0:
                    actual_chars.append(chr(char_val))
            actual = ''.join(actual_chars)
            
            if actual != expected:
                raise TestFailure(f"Word {i}: expected '{expected}', got '{actual}'")
            
            dut._log.info(f"Word {i}: '{actual}' ✓")
        
        dut._log.info("Test passed!
")
    
    # Test cases
    await run_test("Mary had a little lamb", 4, ["little"])
    await run_test("Mary had a little lamb", 3, ["Mary", "lamb"])
    await run_test("simple white space", 2, [])
    await run_test("Hello world", 4, ["world"])
    await run_test("Uncle sam", 3, ["Uncle"])
    await run_test("", 4, [])
    await run_test("a b c d e f", 1, ["b", "c", "d", "f"])
    
    dut._log.info("All 7 tests passed!")
