import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def str_to_bytes(s, length=8):
    """Convert string to fixed-width byte array."""
    bytes_list = [ord(c) for c in s]
    # Pad with spaces (0x20) or nulls (0x00) to length 8
    while len(bytes_list) < length:
        bytes_list.append(0x20)  # Space padding
    return bytes_list

def check_balanced(s):
    """Check if string of parentheses is balanced."""
    depth = 0
    for char in s:
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth < 0:
                return False
    return depth == 0

def expected_result(str1, str2):
    """Calculate expected result."""
    # Check both concatenation orders
    if check_balanced(str1 + str2) or check_balanced(str2 + str1):
        return 1
    return 0

@cocotb.test()
async def test_match_parens(dut):
    """Test match_parens module with various test cases."""
    
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from problem
    test_cases = [
        ('()(', ')', True),   # str1="()(", str2=")" -> balanced
        (')', ')', False),   # str1=")", str2=")" -> not balanced
        ('(()(())', '())())', False),  # Both orders invalid
        (')())', '(()()('), True),     # One order valid
        ('(())))', '(()())(('), True), # One order valid
        ('()', '())', False),          # Both orders invalid
        ('(()(', '()))()', True),      # One order valid
        ('((((', '((())'), False),     # Both orders invalid
        (')(()', '(()('), False),      # Both orders invalid
        (')(', ')(', False),          # Both orders invalid
        ('(', ')', True),              # Balanced
        (')', '(', True),              # Balanced (reverse order)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for str1, str2, expected in test_cases:
        # Convert strings to byte arrays
        bytes1 = str_to_bytes(str1)
        bytes2 = str_to_bytes(str2)
        
        # Load inputs
        for i in range(8):
            dut.str1[i].value = bytes1[i]
            dut.str2[i].value = bytes2[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        exp = 1 if expected else 0
        
        if actual == exp:
            passed += 1
            print(f"PASS: ['{str1}', '{str2}'] -> {exp}")
        else:
            print(f"FAIL: ['{str1}', '{str2}'] expected {exp}, got {actual}")
        
        await RisingEdge(dut.clk)  # Space out tests
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
