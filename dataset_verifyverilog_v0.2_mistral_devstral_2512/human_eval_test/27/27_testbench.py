import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def char_to_ascii(c):
    """Convert character to ASCII value"""
    return ord(c)

def flip_char(c):
    """Flip case of ASCII character"""
    if ord('A') <= c <= ord('Z'):
        return c + 0x20  # to lowercase
    elif ord('a') <= c <= ord('z'):
        return c - 0x20  # to uppercase
    else:
        return c

@cocotb.test()
async def test_flip_case(dut):
    """Test flip_case module with various strings"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    dut.char_index.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_output_string)
    test_cases = [
        ('', ''),  # Empty string
        ('Hello!', 'hELLO!'),  # Mixed case with symbol
        ('AbCd123', 'aBcD123'),  # Mixed case with numbers
        ('ABC', 'abc'),  # All uppercase
        ('xyz', 'XYZ'),  # All lowercase
    ]
    
    tests_passed = 0
    tests_total = len(test_cases)
    
    for input_str, expected_str in test_cases:
        print(f"
Testing: '{input_str}' -> '{expected_str}'")
        
        # Pad to 16 characters with spaces
        padded_input = input_str.ljust(16, ' ')
        expected_padded = expected_str.ljust(16, ' ')
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Process each character
        received_chars = []
        
        for i in range(16):
            # Feed character
            dut.char_in.value = char_to_ascii(padded_input[i])
            dut.char_index.value = i
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
            
            # Wait for output (latency 1 cycle)
            await RisingEdge(dut.clk)
            
            if dut.valid_out.value == 1:
                received_chars.append(chr(int(dut.char_out.value)))
                dut._log.info(f"Index {i}: input='{padded_input[i]}' output='{chr(int(dut.char_out.value))}'")
            
            dut.valid_in.value = 0
        
        # Wait for done
        timeout = 50
        cycles = 0
        while dut.done.value == 0 and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
            if dut.valid_out.value == 1:
                # Might be getting extra outputs
                pass
        
        # Check results
        result_str = ''.join(received_chars)
        print(f"Result: '{result_str}'")
        print(f"Expected: '{expected_padded}'")
        
        if result_str == expected_padded:
            tests_passed += 1
            print(f"PASS: Test {tests_passed}/{tests_total}")
        else:
            raise TestFailure(f"Test failed! Got '{result_str}', expected '{expected_padded}'")
    
    print(f"
=== SUMMARY ===")
    print(f"{tests_passed}/{tests_total} tests passed")
