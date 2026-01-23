import cocotb
from cocotb.triggers import Timer
import random

def str_to_bytes(s):
    """Convert string to 64-bit value (8 chars, little-endian)"""
    val = 0
    for i, char in enumerate(s):
        val |= ord(char) << (8 * i)
    return val

@cocotb.test()
async def test_cycpattern_check(dut):
    """Test cycpattern_check module"""
    
    # Test case helper
    async def test_case(a_str, b_str, expected, test_name):
        a_val = str_to_bytes(a_str)
        b_val = str_to_bytes(b_str)
        len_a = len(a_str)
        len_b = len(b_str)
        
        dut.a.value = a_val
        dut.b.value = b_val
        dut.len_a.value = len_a
        dut.len_b.value = len_b
        
        await Timer(10, units='ns')
        
        result = int(dut.result.value)
        
        print(f"{test_name}: a='{a_str}', b='{b_str}' -> result={result}, expected={expected}")
        assert result == expected, f"{test_name} failed: got {result}, expected {expected}"
    
    # Original test cases
    await test_case("abcd", "abd", 0, "Test 0")
    await test_case("hello", "ell", 1, "Test 1")
    await test_case("whassup", "psus", 0, "Test 2")
    await test_case("abab", "baa", 1, "Test 3")
    await test_case("efef", "eeff", 0, "Test 4")
    await test_case("himenss", "simen", 1, "Test 5")
    
    # Additional test cases from check function
    await test_case("xyzw", "xyw", 0, "Check Test 0")
    await test_case("yello", "ell", 1, "Check Test 1")
    await test_case("whattup", "ptut", 0, "Check Test 2")
    await test_case("efef", "fee", 1, "Check Test 3")
    await test_case("abab", "aabb", 0, "Check Test 4")
    await test_case("winemtt", "tinem", 1, "Check Test 5")
    
    # Edge cases
    await test_case("a", "a", 1, "Single char match")
    await test_case("ab", "ba", 1, "Two char rotation")
    await test_case("abc", "cab", 1, "Three char rotation")
    await test_case("aaa", "aa", 1, "Repeated chars")
    await test_case("abcd", "dcba", 0, "Full reverse no match")
    
    print("All 11 tests passed!")
