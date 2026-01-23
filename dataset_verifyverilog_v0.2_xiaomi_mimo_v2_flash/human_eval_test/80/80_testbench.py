import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_is_happy(dut):
    """Test is_happy module with various string inputs"""
    
    # Helper function to set string and length
    def set_string(s):
        chars = [ord(c) for c in s]
        # Pad with zeros
        while len(chars) < 8:
            chars.append(0)
        
        dut.char_0.value = chars[0]
        dut.char_1.value = chars[1]
        dut.char_2.value = chars[2]
        dut.char_3.value = chars[3]
        dut.char_4.value = chars[4]
        dut.char_5.value = chars[5]
        dut.char_6.value = chars[6]
        dut.char_7.value = chars[7]
        dut.length.value = len(s)
    
    # Test cases: (string, expected_happy)
    test_cases = [
        ("a", False),
        ("aa", False),
        ("abcd", True),
        ("aabb", False),
        ("adb", True),
        ("xyy", False),
        ("iopaxpoi", True),
        ("iopaxioi", False),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_str, expected in test_cases:
        set_string(test_str)
        await Timer(1, units='ns')  # Let combinational logic settle
        
        result = int(dut.is_happy.value)
        expected_val = 1 if expected else 0
        
        if result == expected_val:
            passed += 1
            print(f"PASS: '{test_str}' -> is_happy={result} (expected {expected_val})")
        else:
            print(f"FAIL: '{test_str}' -> is_happy={result} (expected {expected_val})")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
