import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def str_to_bytes(s):
    """Convert string to 16-byte array with 8-bit ASCII"""
    bytes_array = [0] * 16
    for i, c in enumerate(s):
        if i < 16:
            bytes_array[i] = ord(c)
    return bytes_array

def check_validity_python(s):
    """Python reference for bracket validity"""
    balance = 0
    for c in s:
        if c == '(':
            balance += 1
        elif c == ')':
            balance -= 1
        if balance < 0:
            return False
    return balance == 0

def can_be_made_valid(s):
    """Check if one inversion can make it valid"""
    # Check original
    if check_validity_python(s):
        return True
    
    n = len(s)
    # Try all possible inversions
    for l in range(n):
        for r in range(l, n):
            # Invert segment [l,r]
            inverted = list(s)
            for i in range(l, r+1):
                if inverted[i] == '(':
                    inverted[i] = ')'
                else:
                    inverted[i] = '('
            if check_validity_python(inverted):
                return True
    return False

@cocotb.test()
async def test_bracket_validator(dut):
    """Test bracket validator with multiple test cases"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input, expected_result, description)
    test_cases = [
        ("()))", True, "Sample 1: (())) -> invert [3,4] or [3,3] or [2,2]"),
        (")))(", False, "Sample 2: )))(( -> impossible"),
        ("()", True, "Sample 3: () already valid"),
        ("((()))", True, "Already valid nested"),
        (")))((", False, "Mismatched"),
        ("(()()(()", True, "Can fix with inversion"),
        ("))))", False, "All closing, impossible"),
        ("(((", False, "All opening, impossible"),
        ("(", False, "Single opening"),
        (")", True, "Single closing - invert it!"),
        ("", True, "Empty string"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_str, expected, desc in test_cases:
        # Prepare inputs
        byte_array = str_to_bytes(test_str)
        for i in range(16):
            dut.bracket_str[i].value = byte_array[i]
        dut.str_len.value = len(test_str)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 10000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 10000:
            raise TestFailure(f"Test '{desc}' timed out!")
        
        # Check result
        actual = bool(dut.result.value)
        if actual == expected:
            print(f"PASS: {desc}")
            print(f"  Input: '{test_str}' (len={len(test_str)})")
            print(f"  Expected: {expected}, Got: {actual}")
            passed += 1
        else:
            print(f"FAIL: {desc}")
            print(f"  Input: '{test_str}'")
            print(f"  Expected: {expected}, Got: {actual}")
            raise TestFailure(f"Mismatch on '{desc}'")
        
        await RisingEdge(dut.clk)
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    if passed == total:
        print("All tests successful!")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases with zero length and boundary conditions"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test empty string
    for i in range(16):
        dut.bracket_str[i].value = 0
    dut.str_len.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.result.value != 1:
        raise TestFailure("Empty string should be valid")
    print("PASS: Empty string test")
    
    await RisingEdge(dut.clk)
    
    # Test max length valid
    test_str = "()()()()()()()()"  # 16 chars
    for i in range(16):
        dut.bracket_str[i].value = ord(test_str[i])
    dut.str_len.value = 16
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Max length test timed out")
    if dut.result.value != 1:
        raise TestFailure("Max length valid string should work")
    print("PASS: Max length valid test")
