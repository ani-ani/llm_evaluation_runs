import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def is_palindrome(num):
    """Check if a number is a palindrome"""
    s = str(num)
    return s == s[::-1]

def count_palindromes(n):
    """Count even and odd palindromes up to n"""
    even = 0
    odd = 0
    for i in range(1, n + 1):
        if is_palindrome(i):
            if i % 2 == 0:
                even += 1
            else:
                odd += 1
    return even, odd

@cocotb.test()
async def test_even_odd_palindrome(dut):
    """Test the even_odd_palindrome module with various n values"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_even, expected_odd)
    test_cases = [
        (1, 0, 1),      # 1 - palindrome, odd
        (3, 1, 2),      # 1,2,3 - palindromes: 1,2,3 (even:2, odd:1,3)
        (9, 4, 5),      # 1-9 all palindromes (even:2,4,6,8 odd:1,3,5,7,9)
        (12, 4, 6),     # 1-12: 1,2,3,4,5,6,7,8,9,11 (even:2,4,6,8; odd:1,3,5,7,9,11)
        (19, 4, 6),     # 1-19: same as above up to 19, add nothing
        (25, 5, 6),     # 1-25: add 22 (even), total even=5
        (63, 6, 8),     # 1-63: 1,2,3,4,5,6,7,8,9,11,22,33,44,55 (even:2,4,6,8,22,44, odd:1,3,5,7,9,11,33,55)
        (101, 10, 11),  # 1-101: add 101 (odd)
        (123, 8, 13),   # 1-123: 1,2,3,4,5,6,7,8,9,11,22,33,44,55,66,77,88,99,101,111,121 (even:2,4,6,8,22,44,66,88 odd:1,3,5,7,9,11,33,55,77,99,101,111,121)
        (200, 15, 16),  # 1-200: all up to 99 plus 101,111,121,131,141,151,161,171,181,191,202
        (255, 18, 19),  # 1-255: add 212,222,232,242,252
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected_even, expected_odd in test_cases:
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 0
        while not dut.done.value and timeout < 300:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 300:
            print(f"Test n={n}: TIMEOUT")
            continue
        
        # Read results
        even_result = int(dut.even_count.value)
        odd_result = int(dut.odd_count.value)
        
        print(f"n={n}: Expected ({expected_even}, {expected_odd}), Got ({even_result}, {odd_result})")
        
        if even_result == expected_even and odd_result == expected_odd:
            passed += 1
            print(f"  PASS")
        else:
            print(f"  FAIL")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
