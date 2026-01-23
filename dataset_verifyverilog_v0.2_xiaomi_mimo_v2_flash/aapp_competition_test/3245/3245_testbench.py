import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to pack string into 16-bit chunks (2 chars per chunk)
def pack_string(s):
    # Pad to even length
    if len(s) % 2 != 0:
        s += '\x00'
    res = []
    for i in range(0, len(s), 2):
        # Pack high byte first (big endian logic for ease of debugging, though Verilog is usually little endian for arrays)
        # Let's stick to simple byte array logic: char 0 at bit 15-8, char 1 at bit 7-0
        val = (ord(s[i]) << 8) | (ord(s[i+1]) if i+1 < len(s) else 0)
        res.append(val)
    return res

@cocotb.test()
async def test_fish_shell_sim(dut):
    """Test the simplified fish shell simulator"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Simple entry
    # Input: "python"
    dut.start.value = 1
    dut.char_in.value = ord('p')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in ['y', 't', 'h', 'o', 'n', '
']:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
    
    # Wait for output and done
    output_str = ""
    while True:
        if dut.done.value == 1:
            break
        if dut.output_valid.value:
            # Decode result_out (16 bits = 2 chars)
            val = dut.result_out.value.integer
            c1 = (val >> 8) & 0xFF
            c2 = val & 0xFF
            if c1 != 0: output_str += chr(c1)
            if c2 != 0: output_str += chr(c2)
        await RisingEdge(dut.clk)
    
    if output_str != "python":
        raise TestFailure(f"Test 1 Failed: Expected 'python', got '{output_str}'")
    
    # Wait for idle
    await RisingEdge(dut.clk)
    
    # Test Case 2: Prefix + Up + More
    # Input: "p^ main.py"
    # Expected: Start "p", expand to "python", add " main.py" -> "python main.py"
    dut.start.value = 1
    dut.char_in.value = ord('p')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Type '^'
    dut.char_in.value = ord('^')
    await RisingEdge(dut.clk)
    
    # Wait for expansion logic (simulated by checking buffer or state)
    # We just pump cycles until we see the buffer updated or just proceed to next chars
    # In this simple model, we will just type the rest.
    # Note: Real hardware might take cycles to expand. We will be aggressive.
    for _ in range(10): await RisingEdge(dut.clk)
    
    # Now type " main.py"
    for char in [' ', 'm', 'a', 'i', 'n', '.', 'p', 'y', '
']:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
        
    output_str = ""
    while True:
        if dut.done.value == 1:
            break
        if dut.output_valid.value:
            val = dut.result_out.value.integer
            c1 = (val >> 8) & 0xFF
            c2 = val & 0xFF
            if c1 != 0: output_str += chr(c1)
            if c2 != 0: output_str += chr(c2)
        await RisingEdge(dut.clk)
        
    if output_str != "python main.py":
        raise TestFailure(f"Test 2 Failed: Expected 'python main.py', got '{output_str}'")

    await RisingEdge(dut.clk)

    # Test Case 3: Full expansion
    # Input: "^ -n 10"
    # Expected: Expand to "python main.py", add " -n 10" -> "python main.py -n 10"
    dut.start.value = 1
    dut.char_in.value = ord('^')
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10): await RisingEdge(dut.clk)
    
    for char in [' ', '-', 'n', ' ', '1', '0', '
']:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
        
    output_str = ""
    while True:
        if dut.done.value == 1:
            break
        if dut.output_valid.value:
            val = dut.result_out.value.integer
            c1 = (val >> 8) & 0xFF
            c2 = val & 0xFF
            if c1 != 0: output_str += chr(c1)
            if c2 != 0: output_str += chr(c2)
        await RisingEdge(dut.clk)

    if output_str != "python main.py -n 10":
        raise TestFailure(f"Test 3 Failed: Expected 'python main.py -n 10', got '{output_str}'")

    # Summary
    dut._log.info("All tests passed!")