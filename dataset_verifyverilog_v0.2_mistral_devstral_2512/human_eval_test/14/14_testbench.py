import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

# Helper to convert string to byte array
def str_to_bytes(s):
    return [ord(c) for c in s]

# Helper to convert byte array back to string for display
def bytes_to_str(b):
    return ''.join(chr(x) if x != 0 else '' for x in b)

@cocotb.test()
async def test_all_prefixes(dut):
    """Test all_prefixes module with various inputs"""
    
    # Test case 1: Empty string
    dut.input_string.value = [0, 0, 0, 0, 0, 0, 0, 0]
    dut.input_length.value = 0
    await Timer(10, units='ns')
    assert dut.prefix_count.value == 0, f"Empty string: Expected prefix_count=0, got {dut.prefix_count.value}"
    print("Test 1 PASSED: Empty string")
    
    # Test case 2: Single character
    dut.input_string.value = str_to_bytes('a') + [0, 0, 0, 0, 0, 0, 0]
    dut.input_length.value = 1
    await Timer(10, units='ns')
    assert dut.prefix_count.value == 1, f"Single char: Expected prefix_count=1, got {dut.prefix_count.value}"
    prefix0 = [dut.prefixes[0][i].value for i in range(8)]
    assert prefix0[0] == ord('a'), f"Expected 'a' at pos 0, got {prefix0[0]}"
    print("Test 2 PASSED: Single character 'a'")
    
    # Test case 3: Two characters 'ab'
    dut.input_string.value = str_to_bytes('ab') + [0, 0, 0, 0, 0, 0]
    dut.input_length.value = 2
    await Timer(10, units='ns')
    assert dut.prefix_count.value == 2, f"Two chars: Expected prefix_count=2, got {dut.prefix_count.value}"
    # Check prefix 0 = 'a'
    prefix0 = [dut.prefixes[0][i].value for i in range(8)]
    assert prefix0[0] == ord('a'), f"prefix[0] should be 'a', got {chr(prefix0[0])}"
    # Check prefix 1 = 'ab'
    prefix1 = [dut.prefixes[1][i].value for i in range(8)]
    assert prefix1[0] == ord('a'), f"prefix[1][0] should be 'a', got {chr(prefix1[0])}"
    assert prefix1[1] == ord('b'), f"prefix[1][1] should be 'b', got {chr(prefix1[1])}"
    print("Test 3 PASSED: 'ab' -> ['a', 'ab']")
    
    # Test case 4: Three characters 'abc'
    dut.input_string.value = str_to_bytes('abc') + [0, 0, 0, 0, 0]
    dut.input_length.value = 3
    await Timer(10, units='ns')
    assert dut.prefix_count.value == 3, f"Three chars: Expected prefix_count=3, got {dut.prefix_count.value}"
    # Check all three prefixes
    for i, expected in enumerate(['a', 'ab', 'abc']):
        prefix = [dut.prefixes[i][j].value for j in range(8)]
        for k, exp_char in enumerate(expected):
            assert prefix[k] == ord(exp_char), f"prefix[{i}][{k}] should be '{exp_char}', got {chr(prefix[k])}"
    print("Test 4 PASSED: 'abc' -> ['a', 'ab', 'abc']")
    
    # Test case 5: Six characters 'asdfgh'
    input_str = 'asdfgh'
    dut.input_string.value = str_to_bytes(input_str) + [0, 0]
    dut.input_length.value = 6
    await Timer(10, units='ns')
    assert dut.prefix_count.value == 6, f"Expected prefix_count=6, got {dut.prefix_count.value}"
    for i in range(6):
        prefix = [dut.prefixes[i][j].value for j in range(8)]
        for k in range(i+1):
            assert prefix[k] == ord(input_str[k]), f"prefix[{i}][{k}] mismatch"
    print("Test 5 PASSED: 'asdfgh' generates 6 prefixes")
    
    # Test case 6: Three characters 'WWW'
    dut.input_string.value = str_to_bytes('WWW') + [0, 0, 0, 0, 0]
    dut.input_length.value = 3
    await Timer(10, units='ns')
    assert dut.prefix_count.value == 3, f"Expected prefix_count=3, got {dut.prefix_count.value}"
    for i, expected in enumerate(['W', 'WW', 'WWW']):
        prefix = [dut.prefixes[i][j].value for j in range(8)]
        for k, exp_char in enumerate(expected):
            assert prefix[k] == ord(exp_char), f"prefix[{i}][{k}] should be '{exp_char}', got {chr(prefix[k])}"
    print("Test 6 PASSED: 'WWW' -> ['W', 'WW', 'WWW']")
    
    # Test case 7: Full 8-character string
    input_str = 'abcdefgh'
    dut.input_string.value = str_to_bytes(input_str)
    dut.input_length.value = 8
    await Timer(10, units='ns')
    assert dut.prefix_count.value == 8, f"Expected prefix_count=8, got {dut.prefix_count.value}"
    print("Test 7 PASSED: Full 8-character string")
    
    print(f"
=== Summary: All tests passed ===")
