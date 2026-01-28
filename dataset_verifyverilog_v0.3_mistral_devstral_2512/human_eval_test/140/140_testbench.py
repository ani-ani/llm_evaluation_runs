import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure, TestSuccess
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_done(dut, timeout_cycles=20):
    """Wait for the done signal to go high."""
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fix_spaces(dut):
    """Test the fix_spaces module."""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.length.value = 0
    for i in range(8):
        dut.text[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to setup input
    def setup_input(text_str):
        dut.length.value = len(text_str)
        for i in range(8):
            if i < len(text_str):
                dut.text[i].value = ord(text_str[i])
            else:
                dut.text[i].value = 0
    
    # Helper to read output
    def get_output():
        out_str = ""
        if not is_value_defined(dut.out_len.value):
            raise TestFailure("out_len is undefined")
        
        out_len = int(dut.out_len.value)
        for i in range(out_len):
            if i >= 8: break
            if not is_value_defined(dut.result[i].value):
                raise TestFailure(f"result[{i}] is undefined")
            val = int(dut.result[i].value)
            out_str += chr(val)
        return out_str

    # Test cases
    # 1. No spaces -> No change
    # 2. 1 space -> Underscore
    # 3. 2 spaces -> Double underscore
    # 4. >2 spaces -> Hyphen
    # 5. Mixed

    test_cases = [
        ("Example", "Example"),
        ("Example 1", "Example_1"),
        (" Example 2", "_Example_2"),
        (" Example   3", "_Example-3"),
        ("Mudasir Hanif ", "Mudasir_Hanif_"),
        ("Yellow Yellow  Dirty  Fellow", "Yellow_Yellow__Dirty__Fellow"),
        ("Exa   mple", "Exa-mple"),
        ("   Exa 1 2 2 mple", "-Exa_1_2_2_mple"),
    ]

    passed = 0
    total = len(test_cases)

    for text_in, expected in test_cases:
        dut._log.info(f"Testing input: '{text_in}' (len={len(text_in)})")
        
        # Setup input
        setup_input(text_in)
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_ok = await wait_for_done(dut)
        if not done_ok:
            raise TestFailure(f"Timeout waiting for done for input '{text_in}'")
        
        # Read output
        result = get_output()
        
        if result == expected:
            dut._log.info(f"PASS: '{text_in}' -> '{result}'")
            passed += 1
        else:
            raise TestFailure(f"FAIL: '{text_in}' -> Expected '{expected}', got '{result}'")
        
        await RisingEdge(dut.clk)

    dut._log.info(f"Summary: {passed}/{total} tests passed")
