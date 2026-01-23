import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_char_counter(dut):
    """Test character counter module with various string lengths"""
    
    # Test case 1: "python programming" - 18 chars (too long, use first 8 chars "python p")
    dut.str_data.value = 0x70206e6f68747970  # "python p" in ASCII
    dut.str_length.value = 8
    await Timer(1, units='ns')
    assert dut.char_count.value == 8, f"Test 1 failed: expected 8, got {dut.char_count.value}"
    print("Test 1 passed: 'python p' -> 8 chars")
    
    # Test case 2: "language" - 8 chars
    dut.str_data.value = 0x656761676e61756c  # "language" in ASCII
    dut.str_length.value = 8
    await Timer(1, units='ns')
    assert dut.char_count.value == 8, f"Test 2 failed: expected 8, got {dut.char_count.value}"
    print("Test 2 passed: 'language' -> 8 chars")
    
    # Test case 3: "words" - 5 chars
    dut.str_data.value = 0x0000007364726f77  # "words" in ASCII (left-aligned)
    dut.str_length.value = 5
    await Timer(1, units='ns')
    assert dut.char_count.value == 5, f"Test 3 failed: expected 5, got {dut.char_count.value}"
    print("Test 3 passed: 'words' -> 5 chars")
    
    # Edge cases
    # Empty string
    dut.str_data.value = 0
    dut.str_length.value = 0
    await Timer(1, units='ns')
    assert dut.char_count.value == 0, f"Test 4 failed: expected 0, got {dut.char_count.value}"
    print("Test 4 passed: empty string -> 0 chars")
    
    # Single character
    dut.str_data.value = 0x0000000000000061  # 'a'
    dut.str_length.value = 1
    await Timer(1, units='ns')
    assert dut.char_count.value == 1, f"Test 5 failed: expected 1, got {dut.char_count.value}"
    print("Test 5 passed: 'a' -> 1 char")
    
    # Maximum length (8 chars)
    dut.str_data.value = 0x6162636465666768  # "abcdefgh"
    dut.str_length.value = 8
    await Timer(1, units='ns')
    assert dut.char_count.value == 8, f"Test 6 failed: expected 8, got {dut.char_count.value}"
    print("Test 6 passed: 'abcdefgh' -> 8 chars")
    
    print("
6/6 tests passed")