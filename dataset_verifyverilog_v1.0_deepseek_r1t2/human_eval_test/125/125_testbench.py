import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert string to ASCII list
def str_to_ascii(s):
    return [ord(c) for c in s]

@cocotb.test(timeout_time=2, timeout_unit='ms')
async def test_split_words_fsm(dut):
    """Test split_words_fsm module with various string inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    dut.last_char.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_is_split_mode, expected_result, description)
    test_cases = [
        ("Hello world!", 1, 2, "Space delimiter - 2 words"),
        ("Hello,world!", 1, 2, "Comma delimiter - 2 words"),
        ("Hello world,!", 1, 2, "Mixed delimiter - 2 words"),
        ("Hello,Hello,world !", 1, 3, "Multiple delimiters - 3 words"),
        ("abcdef", 0, 3, "No delimiter - counting 'a'(0), 'c'(2), 'e'(4)"),
        ("aaabb", 0, 2, "No delimiter - counting 'a'(0), 'a'(0), 'a'(0), 'b'(1), 'b'(1) -> only 'a' counts"),
        ("aaaBb", 0, 1, "No delimiter - 'a'(0) counts, 'B'(1) not lowercase"),
        ("", 0, 0, "Empty string"),
        ("a", 0, 1, "Single char 'a'"),
        ("b", 0, 0, "Single char 'b'"),
        (" , ", 1, 1, "Only delimiters"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_idx, (input_str, exp_is_split, exp_result, desc) in enumerate(test_cases):
        dut._log.info(f"Test {test_idx}: {desc}")
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters
        ascii_chars = str_to_ascii(input_str)
        
        if not ascii_chars:
            # Empty string case
            dut.valid_in.value = 0
            dut.last_char.value = 1
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
            dut.last_char.value = 0
        else:
            for i, char_val in enumerate(ascii_chars):
                dut.valid_in.value = 1
                dut.char_in.value = char_val
                dut.last_char.value = 1 if (i == len(ascii_chars) - 1) else 0
                await RisingEdge(dut.clk)
            
            dut.valid_in.value = 0
            dut.last_char.value = 0
        
        # Wait for done with timeout
        timeout_cycles = 20
        done_found = False
        
        for cycle in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {test_idx} Timeout: done signal not asserted after {timeout_cycles} cycles")
        
        # Verify outputs
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {test_idx}: result is undefined (X/Z)")
        
        if not is_value_defined(dut.is_split_mode.value):
            raise TestFailure(f"Test {test_idx}: is_split_mode is undefined (X/Z)")
        
        actual_result = int(dut.result.value)
        actual_mode = int(dut.is_split_mode.value)
        
        if actual_mode != exp_is_split:
            raise TestFailure(f"Test {test_idx} ({desc}): Expected mode={exp_is_split}, got {actual_mode}")
        
        if actual_result != exp_result:
            raise TestFailure(f"Test {test_idx} ({desc}): Expected result={exp_result}, got {actual_result}")
        
        dut._log.info(f"  Passed: Mode={actual_mode}, Result={actual_result}")
        passed += 1
        
        # Small gap between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Some tests failed: {passed}/{total}")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_reset_behavior(dut):
    """Verify reset behavior works correctly"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset high
    dut.rst_n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    # Reset low in middle of operation
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Check done is cleared
    if is_value_defined(dut.done.value) and dut.done.value == 1:
        raise TestFailure("Done should be 0 after reset")
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Should be ready for new operation
    dut.start.value = 0
    dut._log.info("Reset test passed")
