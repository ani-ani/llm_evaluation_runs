import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

def str_to_bytes(s, max_len=8):
    """Convert Python string to list of bytes for Verilog input"""
    bytes_list = []
    for i in range(max_len):
        if i < len(s):
            bytes_list.append(ord(s[i]))
        else:
            bytes_list.append(0)
    return bytes_list

def remove_whitespace_python(s):
    """Reference function"""
    return ''.join(c for c in s if c != ' ')

@cocotb.test()
async def test_remove_whitespaces(dut):
    """Test whitespace removal with various strings"""
    
    # Test cases from original problem
    test_cases = [
        (' Google    ', 'Google'),  # Modified to fit 8 char limit
        (' Google    D', 'GoogleD'),
        (' iOS    Swi', 'iOSSwi'),
        ('  ', ''),  # All spaces
        ('Hello', 'Hello'),  # No spaces
        ('A B C D', 'ABCD'),  # Multiple single spaces
        ('        ', ''),  # 8 spaces
        ('!@# $%^&', '!@#$%^&'),  # Special chars
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected_str in test_cases:
        # Prepare inputs
        input_bytes = str_to_bytes(input_str, max_len=8)
        input_len = len(input_str)
        
        # Set inputs
        for i in range(8):
            setattr(dut, f'text_in_{i}', input_bytes[i])
        dut.length_in.value = input_len
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        output_bytes = [int(getattr(dut, f'text_out_{i}').value) for i in range(8)]
        output_len = int(dut.length_out.value)
        
        # Convert to string
        output_str = ''.join(chr(b) for b in output_bytes[:output_len])
        
        # Verify
        if output_str == expected_str and output_len == len(expected_str):
            passed += 1
            print(f"✓ Test '{input_str}' -> '{output_str}' (len={output_len})")
        else:
            print(f"✗ Test '{input_str}' failed: got '{output_str}' (len={output_len}), expected '{expected_str}' (len={len(expected_str)})")
    
    print(f"
Results: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"