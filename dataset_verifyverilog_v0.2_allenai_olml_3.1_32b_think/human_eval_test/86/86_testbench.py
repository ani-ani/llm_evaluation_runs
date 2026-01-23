import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def char_to_byte(c):
    """Convert ASCII character to byte value"""
    return ord(c) if c else 0

def string_to_array(s, length=16):
    """Convert string to fixed-width byte array"""
    arr = [0] * length
    for i, c in enumerate(s[:length]):
        arr[i] = char_to_byte(c)
    return arr

def byte_to_char(b):
    """Convert byte to ASCII character"""
    if b == 0:
        return ''
    return chr(b)

def array_to_string(arr):
    """Convert byte array back to string"""
    s = ''
    for b in arr:
        if b != 0:
            s += chr(b)
    return s

def sort_word_chars(chars):
    """Sort alphabetic characters in a word segment"""
    # Filter alphabetic characters
    alpha = [c for c in chars if (0x41 <= c <= 0x5A) or (0x61 <= c <= 0x7A)]
    non_alpha = [(i, c) for i, c in enumerate(chars) if not ((0x41 <= c <= 0x5A) or (0x61 <= c <= 0x7A))]
    
    # Sort alphabetic characters
    alpha.sort()
    
    # Reconstruct
    result = []
    alpha_idx = 0
    for i in range(len(chars)):
        if i in [ni for ni, _ in non_alpha]:
            result.append(dict(non_alpha)[i])
        else:
            result.append(alpha[alpha_idx])
            alpha_idx += 1
    
    return result

def anti_shuffle_expected(input_str):
    """Expected output for anti_shuffle"""
    # Convert to byte array
    bytes_in = [char_to_byte(c) for c in input_str]
    
    # Process word by word
    result = []
    current_word = []
    current_word_indices = []
    
    for i, b in enumerate(bytes_in):
        # Check if alphabetic
        is_alpha = (0x41 <= b <= 0x5A) or (0x61 <= b <= 0x7A)
        
        if is_alpha:
            current_word.append(b)
            current_word_indices.append(i)
        else:
            # Process completed word
            if current_word:
                sorted_word = sorted(current_word)
                for idx, val in zip(current_word_indices, sorted_word):
                    while len(result) <= idx:
                        result.append(0)
                    result[idx] = val
                current_word = []
                current_word_indices = []
            # Add non-alphabetic character
            while len(result) <= i:
                result.append(0)
            result[i] = b
    
    # Handle trailing word
    if current_word:
        sorted_word = sorted(current_word)
        for idx, val in zip(current_word_indices, sorted_word):
            while len(result) <= idx:
                result.append(0)
            result[idx] = val
    
    # Pad to 16
    while len(result) < 16:
        result.append(0)
    
    return result[:16]

@cocotb.test()
async def test_anti_shuffle(dut):
    """Test anti_shuffle module with various string inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ('Hi', 'Hi'),
        ('hello', 'ehllo'),
        ('number', 'bemnru'),
        ('abcd', 'abcd'),
        ('Hello World!!!', 'Hello !!!Wdlor'),
        ('', ''),
        ('Hi. My name is Mister Robot. How are you?', '.Hi My aemn is Meirst .Rboot How aer ?ouy'),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        print(f"Test {i+1}: Input='{input_str}' -> Expected='{expected_str}'")
        
        # Setup input
        input_array = string_to_array(input_str)
        for j in range(16):
            dut.input_string[j].value = input_array[j]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 300 cycles for safety)
        cycles = 0
        while not dut.done.value and cycles < 300:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= 300:
            print(f"  FAIL: Timeout waiting for done signal")
            continue
        
        # Read result
        result_array = [int(dut.result_string[j].value) for j in range(16)]
        result_str = array_to_string(result_array)
        
        print(f"  Got: '{result_str}' in {cycles} cycles")
        
        # Verify
        if result_str == expected_str:
            print(f"  PASS")
            passed += 1
        else:
            print(f"  FAIL: Expected '{expected_str}', got '{result_str}'")
            # Also print hex for debugging
            print(f"  Expected hex: {[hex(b) for b in anti_shuffle_expected(input_str)]}")
            print(f"  Got hex: {[hex(b) for b in result_array]}")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    if passed == total:
        print("All tests passed!")
    else:
        raise TestFailure(f"{total - passed} test(s) failed")
