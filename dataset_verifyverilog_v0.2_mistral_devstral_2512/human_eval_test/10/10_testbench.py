import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_make_palindrome(dut):
    """Test make_palindrome module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_len.value = 0
    for i in range(16):
        dut.str_data[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Helper function to convert string to byte array
    def str_to_array(s):
        arr = [ord(c) for c in s]
        arr.extend([0] * (16 - len(arr)))
        return arr
    
    # Helper function to check result
    async def check_palindrome(input_str, expected):
        dut.start.value = 1
        dut.str_len.value = len(input_str)
        arr = str_to_array(input_str)
        for i in range(16):
            dut.str_data[i].value = arr[i]
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 300
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        if dut.done.value != 1:
            raise TestFailure(f"Timeout for input '{input_str}'")
        
        result_len = int(dut.result_len.value)
        result_data = [int(dut.result_data[i].value) for i in range(result_len)]
        result_str = ''.join(chr(c) for c in result_data)
        
        if result_str != expected:
            raise TestFailure(f"Input: '{input_str}', Expected: '{expected}', Got: '{result_str}'")
        
        print(f"PASS: '{input_str}' -> '{result_str}'")
    
    # Test cases
    print("
=== Running Test Cases ===")
    
    # Test 1: Empty string
    await check_palindrome('', '')
    
    # Test 2: Single character
    await check_palindrome('x', 'x')
    
    # Test 3: No palindrome suffix (cat)
    await check_palindrome('cat', 'catac')
    
    # Test 4: Full string palindrome (xyx)
    await check_palindrome('xyx', 'xyx')
    
    # Test 5: Multiple characters (jerry)
    await check_palindrome('jerry', 'jerryrrej')
    
    # Additional edge case: "cata" - longest suffix "a" -> catac
    await check_palindrome('cata', 'catac')
    
    print("
=== All 6 tests passed! ===")
    print(f"Total: 6/6 tests passed")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases with maximum length and special patterns"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_len.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    def str_to_array(s):
        arr = [ord(c) for c in s]
        arr.extend([0] * (16 - len(arr)))
        return arr
    
    async def check_palindrome(input_str, expected):
        dut.start.value = 1
        dut.str_len.value = len(input_str)
        arr = str_to_array(input_str)
        for i in range(16):
            dut.str_data[i].value = arr[i]
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 300
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        if dut.done.value != 1:
            raise TestFailure(f"Timeout for input '{input_str}'")
        
        result_len = int(dut.result_len.value)
        result_data = [int(dut.result_data[i].value) for i in range(result_len)]
        result_str = ''.join(chr(c) for c in result_data)
        
        if result_str != expected:
            raise TestFailure(f"Input: '{input_str}', Expected: '{expected}', Got: '{result_str}'")
        
        print(f"PASS: '{input_str}' -> '{result_str}'")
    
    print("
=== Running Edge Cases ===")
    
    # Test: two character string "ab"
    await check_palindrome('ab', 'aba')
    
    # Test: two character palindrome "aa"
    await check_palindrome('aa', 'aa')
    
    # Test: "abc" -> 'abcba'
    await check_palindrome('abc', 'abcba')
    
    # Test: "abcd" -> 'abcdcba'
    await check_palindrome('abcd', 'abcdcba')
    
    # Test: longer string with palindrome in middle
    await check_palindrome('abac', 'abacaba')
    
    print("
=== All edge case tests passed! ===")
    print(f"Total: 5/5 tests passed")
