import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_pattern_matcher(dut):
    """Test the pattern matcher for various string inputs"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.valid_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    # Strings are padded to 16 chars with nulls (0) or spaces if needed, 
    # but we will drive exactly 16 cycles.
    test_cases = [
        ("ac", 0),              # No match
        ("dc", 0),              # No match
        ("abbbba", 1),          # Match
        ("caacabbbba", 1),      # Match
        ("abbbb", 1),           # Match (contains abbb)
        ("ab", 0),              # No match
        ("aabbb", 1),           # Match
        ("a", 0),               # No match
    ]
    
    passed = 0
    total = len(test_cases)
    
    for s, expected_match in test_cases:
        dut._log.info(f"Testing string: '{s}' (Expected Match: {expected_match})")
        
        # Start the scan
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed 16 characters
        chars = list(s)
        
        for i in range(16):
            if i < len(chars):
                dut.char_in.value = ord(chars[i])
                dut.valid_in.value = 1
            else:
                # Pad with nulls
                dut.char_in.value = 0
                dut.valid_in.value = 1
            
            await RisingEdge(dut.clk)
            
            # Optional: Check match immediately if we expect it early
            # But let's wait for completion for consistency
        
        # Wait for done to be asserted (should be high now)
        if dut.done.value != 1:
            raise TestFailure(f"Done not asserted for string '{s}'")
            
        # Check match result
        match_val = int(dut.match.value)
        
        if match_val == expected_match:
            dut._log.info(f"PASSED: '{s}' -> Match={match_val}")
            passed += 1
        else:
            raise TestFailure(f"FAILED: '{s}' -> Expected {expected_match}, got {match_val}")

    dut._log.info(f"
Summary: {passed}/{total} tests passed")
