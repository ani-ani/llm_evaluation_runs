import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_substring_counter(dut):
    """Test the substring counter module with various inputs."""
    
    # Helper function to convert string to 8-byte array
    def str_to_bytes(s):
        bytes_array = [0] * 8
        for i, ch in enumerate(s[:8]):
            bytes_array[i] = ord(ch)
        return bytes_array
    
    # Test cases scaled to 8-byte array format
    test_cases = [
        ("abc", 6),      # length 3: 3*4/2 = 6
        ("abcd", 10),    # length 4: 4*5/2 = 10
        ("abcde", 15),   # length 5: 5*6/2 = 15
        ("a", 1),        # length 1: 1*2/2 = 1
        ("", 0),         # length 0: 0
        ("abcdefgh", 36), # length 8: 8*9/2 = 36
        ("ab\x00cde", 3) # length 2: 2*3/2 = 3 (terminated by null)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for string_input, expected in test_cases:
        # Convert string to 8-byte array
        bytes_array = str_to_bytes(string_input)
        
        # Drive inputs
        dut.char_0.value = bytes_array[0]
        dut.char_1.value = bytes_array[1]
        dut.char_2.value = bytes_array[2]
        dut.char_3.value = bytes_array[3]
        dut.char_4.value = bytes_array[4]
        dut.char_5.value = bytes_array[5]
        dut.char_6.value = bytes_array[6]
        dut.char_7.value = bytes_array[7]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        result = int(dut.result.value)
        
        # Assert
        if result == expected:
            passed += 1
            print(f"Test '{string_input}' passed: result={result} (expected {expected})")
        else:
            print(f"Test '{string_input}' FAILED: result={result} (expected {expected})")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"