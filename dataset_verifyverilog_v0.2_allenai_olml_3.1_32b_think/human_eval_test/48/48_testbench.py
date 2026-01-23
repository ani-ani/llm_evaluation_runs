import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_palindrome_checker(dut):
    """Test the palindrome checker module with various string lengths and patterns"""
    
    # Test case 1: Empty string (length 0)
    dut.valid_count.value = 0
    dut.char_0.value = 0
    dut.char_1.value = 0
    dut.char_2.value = 0
    dut.char_3.value = 0
    dut.char_4.value = 0
    dut.char_5.value = 0
    dut.char_6.value = 0
    dut.char_7.value = 0
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 1, f"Empty string should be palindrome, got {dut.is_palindrome.value}"
    print("Test 1 passed: Empty string is palindrome")
    
    # Test case 2: Single character 'a' (length 1)
    dut.valid_count.value = 1
    dut.char_0.value = ord('a')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 1, f"Single character should be palindrome, got {dut.is_palindrome.value}"
    print("Test 2 passed: Single character is palindrome")
    
    # Test case 3: "aba" (length 3, palindrome)
    dut.valid_count.value = 3
    dut.char_0.value = ord('a')
    dut.char_1.value = ord('b')
    dut.char_2.value = ord('a')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 1, f"'aba' should be palindrome, got {dut.is_palindrome.value}"
    print("Test 3 passed: 'aba' is palindrome")
    
    # Test case 4: "aaaaa" (length 5, palindrome)
    dut.valid_count.value = 5
    dut.char_0.value = ord('a')
    dut.char_1.value = ord('a')
    dut.char_2.value = ord('a')
    dut.char_3.value = ord('a')
    dut.char_4.value = ord('a')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 1, f"'aaaaa' should be palindrome, got {dut.is_palindrome.value}"
    print("Test 4 passed: 'aaaaa' is palindrome")
    
    # Test case 5: "zbcd" (length 4, not palindrome)
    dut.valid_count.value = 4
    dut.char_0.value = ord('z')
    dut.char_1.value = ord('b')
    dut.char_2.value = ord('c')
    dut.char_3.value = ord('d')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 0, f"'zbcd' should not be palindrome, got {dut.is_palindrome.value}"
    print("Test 5 passed: 'zbcd' is not palindrome")
    
    # Test case 6: "xywyx" (length 5, palindrome)
    dut.valid_count.value = 5
    dut.char_0.value = ord('x')
    dut.char_1.value = ord('y')
    dut.char_2.value = ord('w')
    dut.char_3.value = ord('y')
    dut.char_4.value = ord('x')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 1, f"'xywyx' should be palindrome, got {dut.is_palindrome.value}"
    print("Test 6 passed: 'xywyx' is palindrome")
    
    # Test case 7: "xywyz" (length 5, not palindrome)
    dut.valid_count.value = 5
    dut.char_0.value = ord('x')
    dut.char_1.value = ord('y')
    dut.char_2.value = ord('w')
    dut.char_3.value = ord('y')
    dut.char_4.value = ord('z')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 0, f"'xywyz' should not be palindrome, got {dut.is_palindrome.value}"
    print("Test 7 passed: 'xywyz' is not palindrome")
    
    # Test case 8: "xywzx" (length 5, not palindrome)
    dut.valid_count.value = 5
    dut.char_0.value = ord('x')
    dut.char_1.value = ord('y')
    dut.char_2.value = ord('w')
    dut.char_3.value = ord('z')
    dut.char_4.value = ord('x')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 0, f"'xywzx' should not be palindrome, got {dut.is_palindrome.value}"
    print("Test 8 passed: 'xywzx' is not palindrome")
    
    # Test case 9: "abba" (length 4, palindrome)
    dut.valid_count.value = 4
    dut.char_0.value = ord('a')
    dut.char_1.value = ord('b')
    dut.char_2.value = ord('b')
    dut.char_3.value = ord('a')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 1, f"'abba' should be palindrome, got {dut.is_palindrome.value}"
    print("Test 9 passed: 'abba' is palindrome")
    
    # Test case 10: "abca" (length 4, not palindrome)
    dut.valid_count.value = 4
    dut.char_0.value = ord('a')
    dut.char_1.value = ord('b')
    dut.char_2.value = ord('c')
    dut.char_3.value = ord('a')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 0, f"'abca' should not be palindrome, got {dut.is_palindrome.value}"
    print("Test 10 passed: 'abca' is not palindrome")
    
    # Test case 11: "aabbccaa" (length 8, palindrome)
    dut.valid_count.value = 8
    dut.char_0.value = ord('a')
    dut.char_1.value = ord('a')
    dut.char_2.value = ord('b')
    dut.char_3.value = ord('b')
    dut.char_4.value = ord('c')
    dut.char_5.value = ord('c')
    dut.char_6.value = ord('a')
    dut.char_7.value = ord('a')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 1, f"'aabbccaa' should be palindrome, got {dut.is_palindrome.value}"
    print("Test 11 passed: 'aabbccaa' is palindrome")
    
    # Test case 12: "aabbccab" (length 8, not palindrome)
    dut.valid_count.value = 8
    dut.char_0.value = ord('a')
    dut.char_1.value = ord('a')
    dut.char_2.value = ord('b')
    dut.char_3.value = ord('b')
    dut.char_4.value = ord('c')
    dut.char_5.value = ord('c')
    dut.char_6.value = ord('a')
    dut.char_7.value = ord('b')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 0, f"'aabbccab' should not be palindrome, got {dut.is_palindrome.value}"
    print("Test 12 passed: 'aabbccab' is not palindrome")
    
    # Test case 13: Two character palindrome "aa"
    dut.valid_count.value = 2
    dut.char_0.value = ord('a')
    dut.char_1.value = ord('a')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 1, f"'aa' should be palindrome, got {dut.is_palindrome.value}"
    print("Test 13 passed: 'aa' is palindrome")
    
    # Test case 14: Two character non-palindrome "ab"
    dut.valid_count.value = 2
    dut.char_0.value = ord('a')
    dut.char_1.value = ord('b')
    await Timer(10, units='ns')
    assert dut.is_palindrome.value == 0, f"'ab' should not be palindrome, got {dut.is_palindrome.value}"
    print("Test 14 passed: 'ab' is not palindrome")
    
    print("
All tests passed!")
