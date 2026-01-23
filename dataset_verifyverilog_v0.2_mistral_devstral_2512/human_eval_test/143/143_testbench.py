import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_words_in_sentence(dut):
    """Test words_in_sentence module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.sentence.value = 0
    dut.valid_len.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert string to hex
    def str_to_hex(s):
        hex_val = 0
        for i, char in enumerate(s):
            hex_val |= (ord(char) << (8 * i))
        return hex_val
    
    # Helper function to convert hex to string
    def hex_to_str(hex_val, length):
        s = ""
        for i in range(length):
            byte_val = (hex_val >> (8 * i)) & 0xFF
            s += chr(byte_val)
        return s
    
    # Test cases
    test_cases = [
        ("This is a test", "is"),
        ("lets go for swimming", "go for"),
        ("there is no place available here", "there is no place"),
        ("Hi I am Hussein", "Hi am Hussein"),
        ("go for it", "go for it"),
        ("here", ""),
        ("here is", "is"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected in test_cases:
        # Skip if input is longer than 16 chars (adapted constraint)
        if len(input_str) > 16:
            print(f"Skipping '{input_str}' - too long for adapted constraint")
            total -= 1
            continue
            
        print(f"Testing: '{input_str}' -> '{expected}'")
        
        # Load input
        dut.sentence.value = str_to_hex(input_str)
        dut.valid_len.value = len(input_str)
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 50
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Timeout waiting for done signal for input '{input_str}'")
        
        # Read result
        result_hex = int(dut.result.value)
        result_len = int(dut.result_len.value)
        result_str = hex_to_str(result_hex, result_len)
        
        print(f"  Input: '{input_str}'")
        print(f"  Expected: '{expected}'")
        print(f"  Got: '{result_str}'")
        
        if result_str != expected:
            raise TestFailure(f"Test failed! Expected '{expected}', got '{result_str}'")
        
        passed += 1
        await Timer(10, units='ns')
        
    print(f"
=== Summary: {passed}/{total} tests passed ===")
