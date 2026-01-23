import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_start_withp(dut):
    """Test start_withp module with various inputs"""
    
    # Helper function to convert string to 10-byte input
    def str_to_bytes(s):
        bytes_list = [ord(c) for c in s]
        # Pad to 10 bytes with zeros
        while len(bytes_list) < 10:
            bytes_list.append(0)
        # Truncate to 10 bytes
        return bytes_list[:10]
    
    # Helper to pack into 80-bit vector
    def pack_input(bytes_list):
        val = 0
        for i, b in enumerate(bytes_list):
            val |= (b << (i * 8))
        return val
    
    # Helper to extract word from output signals
    def get_word(dut, word_num):
        if word_num == 1:
            chars = [dut.word1_char0, dut.word1_char1, dut.word1_char2, dut.word1_char3,
                     dut.word1_char4, dut.word1_char5, dut.word1_char6, dut.word1_char7]
        else:
            chars = [dut.word2_char0, dut.word2_char1, dut.word2_char2, dut.word2_char3,
                     dut.word2_char4, dut.word2_char5, dut.word2_char6, dut.word2_char7]
        
        word = ""
        for char in chars:
            val = char.value
            if val != 0:
                word += chr(val)
        return word
    
    # Test cases
    test_cases = [
        ("Python PHP", "Python", "PHP"),
        ("Python Programming", "Python", "Programming"),
        ("Pqrst Pqr", "Pqrst", "Pqr"),
        ("p test p", "p", "p"),
        ("AA P BB P", "P", "P"),
        ("No matches", "", ""),
        ("P only", "", ""),
        ("Pp Pp", "Pp", "Pp"),
        ("PYTHON PHP", "PYTHON", "PHP"),
        ("PythonP", "", "")  # No space between words
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected_w1, expected_w2) in enumerate(test_cases):
        print(f"
Test {i+1}: Input = '{input_str}'")
        
        # Convert input to bytes and pack
        bytes_list = str_to_bytes(input_str)
        dut.input_string.value = pack_input(bytes_list)
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Extract results
        found = dut.found.value
        word1 = get_word(dut, 1)
        word2 = get_word(dut, 2)
        
        print(f"  Found: {bool(found)}")
        print(f"  Word1: '{word1}' (expected '{expected_w1}')")
        print(f"  Word2: '{word2}' (expected '{expected_w2}')")
        
        # Check results
        if found:
            if word1 == expected_w1 and word2 == expected_w2:
                print("  PASS")
                passed += 1
            else:
                print("  FAIL: Words don't match expected")
        else:
            if expected_w1 == "" and expected_w2 == "":
                print("  PASS")
                passed += 1
            else:
                print("  FAIL: Should have found words")
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    assert passed == total, f"Only {passed} out of {total} tests passed"
