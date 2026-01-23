import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_wire_untangle(dut):
    """Test wire untangle module with various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    dut.end_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_result)
    # '+' encoded as 1, '-' encoded as 2
    test_cases = [
        ("-++-", True),   # Example 1
        ("+-", False),    # Example 2
        ("++", True),     # Example 3
        ("-", False),     # Example 4
        ("-+-+-", False), # Should remain
        ("++--", True),   # Should collapse
        ("--++", True),   # Should collapse
        ("++", True),
        ("--", True),
        ("+-", False),
        ("-+", False),
        ("++-", False),
        ("--++--", True), # Complex collapse
        ("++-+-", False), # Stuck in middle
        ("", True),       # Empty string
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected in test_cases:
        dut._log.info(f"Testing input: '{input_str}' expecting {'Yes' if expected else 'No'}")
        
        # Wait for IDLE state
        await RisingEdge(dut.clk)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters
        for char in input_str:
            if char == '+':
                dut.char_in.value = 1
            elif char == '-':
                dut.char_in.value = 2
            else:
                dut.char_in.value = 0
            
            dut.valid_in.value = 1
            dut.end_in.value = 0
            await RisingEdge(dut.clk)
        
        # Send end signal
        dut.valid_in.value = 0
        dut.end_in.value = 1
        await RisingEdge(dut.clk)
        dut.end_in.value = 0
        
        # Wait for done
        timeout = 50
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            raise TestFailure(f"Timeout waiting for done on input '{input_str}'")
        
        # Check result
        result = bool(dut.result.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Result={result}")
        else:
            raise TestFailure(f"FAIL: Input '{input_str}' got {result}, expected {expected}")
    
    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
