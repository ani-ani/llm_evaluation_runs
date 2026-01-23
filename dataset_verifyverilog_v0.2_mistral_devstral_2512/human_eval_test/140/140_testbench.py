import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_fix_spaces(dut):
    """Test the fix_spaces module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.text_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    def str_to_bytes(s, width=16):
        """Convert string to 128-bit value (16 chars x 8 bits)"""
        s = s.ljust(width, '\x00')[:width]
        val = 0
        for i, ch in enumerate(s):
            val |= ord(ch) << (8 * i)
        return val
    
    def bytes_to_str(val, width=16):
        """Convert 128-bit value back to string"""
        s = ''
        for i in range(width):
            ch = (val >> (8 * i)) & 0xFF
            if ch == 0:
                break
            s += chr(ch)
        return s
    
    test_cases = [
        ("Example", "Example"),
        ("Mudasir Hanif ", "Mudasir_Hanif_"),
        ("Yellow Yellow  Dirty  Fellow", "Yellow_Yellow__Dirty__Fellow"),
        ("Exa   mple", "Exa-mple"),
        ("   Exa 1 2 2 mple", "-Exa_1_2_2_mple"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        # Prepare input
        dut.text_in.value = str_to_bytes(input_str)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Read output
        output_val = dut.text_in.value
        output_str = bytes_to_str(output_val)
        
        # Check result
        if output_str == expected_str:
            passed += 1
            print(f"Test {i+1} PASSED: '{input_str}' -> '{output_str}'")
        else:
            print(f"Test {i+1} FAILED: '{input_str}' -> '{output_str}' (expected '{expected_str}')")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"