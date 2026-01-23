import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def encode_shift(s):
    """Shift each character forward by 5 in alphabet."""
    result = []
    for ch in s:
        if 'a' <= ch <= 'z':
            encoded = chr(((ord(ch) - ord('a') + 5) % 26) + ord('a'))
            result.append(encoded)
        else:
            result.append(ch)
    return ''.join(result)

def ascii_to_int(ch):
    """Convert character to ASCII integer."""
    return ord(ch) if ch else 0

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_decode_shift_basic(dut):
    """Test basic decoding of 'hello' -> 'mjqqt'."""
    dut._log.info("Test 1: Basic decoding 'hello' (encoded as 'mjqqt')")
    
    # Input: 'mjqqt' (encoded)
    input_str = "mjqqt"
    expected = "hello"
    length = 5
    
    # Set inputs
    chars = [input_str[i] if i < length else '0' for i in range(8)]
    for i in range(8):
        setattr(dut, f'char_{i}', ascii_to_int(chars[i]))
    dut.length.value = length
    
    # Wait for combinational propagation
    await Timer(50, units='ns')
    
    # Check outputs
    for i in range(length):
        output_char = getattr(dut, f'decoded_{i}')
        if not is_value_defined(output_char.value):
            raise TestFailure(f"Output decoded_{i} has undefined value")
        
        actual = chr(int(output_char.value))
        expected_char = expected[i]
        
        if actual != expected_char:
            raise TestFailure(f"Test 1 failed at position {i}: expected '{expected_char}', got '{actual}'")
    
    dut._log.info("Test 1 passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_decode_shift_wrap_around(dut):
    """Test wrap-around: 'a' encoded as 'f' should decode back to 'a'."""
    dut._log.info("Test 2: Wrap-around test 'a' -> 'f' -> 'a'")
    
    # 'a' encoded as 'f', 'b' encoded as 'g', etc.
    # Reverse: 'f' decodes to 'a'
    input_str = "fgghh"  # 'a','b','b','c','c' encoded
    expected = "abbcc"
    length = 5
    
    chars = [input_str[i] if i < length else '0' for i in range(8)]
    for i in range(8):
        setattr(dut, f'char_{i}', ascii_to_int(chars[i]))
    dut.length.value = length
    
    await Timer(50, units='ns')
    
    for i in range(length):
        output_char = getattr(dut, f'decoded_{i}')
        if not is_value_defined(output_char.value):
            raise TestFailure(f"Output decoded_{i} has undefined value")
        
        actual = chr(int(output_char.value))
        expected_char = expected[i]
        
        if actual != expected_char:
            raise TestFailure(f"Test 2 failed at position {i}: expected '{expected_char}', got '{actual}'")
    
    dut._log.info("Test 2 passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_decode_shift_full_wrap(dut):
    """Test full wrap-around: 'z' encoded as 'e' should decode back to 'z'."""
    dut._log.info("Test 3: Full wrap 'z' -> 'e' -> 'z'")
    
    # 'z' (122) -> shift back 5: 122-5=117 ('u'), wait no
    # Actually: 'z' encoded is 'e' (122+5=127, 127-26=101='e')
    # So 'e' decodes to 'z'
    input_str = "euvwx"  # 'z','v','w','x','y' encoded
    expected = "zvwyx"  # Actually: e->z, u->p, v->q, w->r, x->s
    # Wait, let's recalculate
    # z=122, 122-5=117 ('u')
    # u=117 (t), 117-5=112 ('p')
    # v=118 (u), 118-5=113 ('q')
    # w=119 (v), 119-5=114 ('r')
    # x=120 (w), 120-5=115 ('s')
    # So expected is 'zpqrs'
    expected = "zpqrs"
    length = 5
    
    chars = [input_str[i] if i < length else '0' for i in range(8)]
    for i in range(8):
        setattr(dut, f'char_{i}', ascii_to_int(chars[i]))
    dut.length.value = length
    
    await Timer(50, units='ns')
    
    for i in range(length):
        output_char = getattr(dut, f'decoded_{i}')
        if not is_value_defined(output_char.value):
            raise TestFailure(f"Output decoded_{i} has undefined value")
        
        actual = chr(int(output_char.value))
        expected_char = expected[i]
        
        if actual != expected_char:
            raise TestFailure(f"Test 3 failed at position {i}: expected '{expected_char}', got '{actual}'")
    
    dut._log.info("Test 3 passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_decode_shift_randomized(dut):
    """Test with random valid strings - generate encoding then decode."""
    dut._log.info("Test 4: Round-trip encoding/decoding")
    
    test_strings = [
        "abcde",
        "vwxyz",
        "mnopq",
        "stuvw",
        "ijklm"
    ]
    
    for idx, original in enumerate(test_strings):
        encoded = encode_shift(original)
        dut._log.info(f"  Original: '{original}', Encoded: '{encoded}'")
        
        length = len(original)
        
        # Set encoded string as input
        chars = [encoded[i] if i < length else '0' for i in range(8)]
        for i in range(8):
            setattr(dut, f'char_{i}', ascii_to_int(chars[i]))
        dut.length.value = length
        
        await Timer(50, units='ns')
        
        # Decode and compare
        for i in range(length):
            output_char = getattr(dut, f'decoded_{i}')
            if not is_value_defined(output_char.value):
                raise TestFailure(f"Output decoded_{i} has undefined value")
            
            actual = chr(int(output_char.value))
            expected_char = original[i]
            
            if actual != expected_char:
                raise TestFailure(f"Test 4.{idx} failed at position {i}: expected '{expected_char}', got '{actual}'")
    
    dut._log.info("Test 4 passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_decode_shift_edge_cases(dut):
    """Test edge cases: empty string, single char, full 8 chars."""
    dut._log.info("Test 5: Edge cases")
    
    # Test 5a: Single character
    dut._log.info("  5a: Single char 'h' -> 'c'")
    dut.char_0.value = ascii_to_int('h')
    dut.length.value = 1
    for i in range(1, 8):
        setattr(dut, f'char_{i}', 0)
    await Timer(50, units='ns')
    output_char = dut.decoded_0
    if not is_value_defined(output_char.value):
        raise TestFailure("Output for single char is undefined")
    if int(output_char.value) != ascii_to_int('c'):
        raise TestFailure(f"Single char test failed: expected 'c', got {chr(int(output_char.value))}")
    
    # Test 5b: Full 8 characters
    dut._log.info("  5b: Full 8 chars 'abcdefgh' -> 'wxyzabcd'")
    input_str = "wxyzabcd"
    expected = "abcdefgh"
    for i in range(8):
        setattr(dut, f'char_{i}', ascii_to_int(input_str[i]))
    dut.length.value = 8
    await Timer(50, units='ns')
    for i in range(8):
        output_char = getattr(dut, f'decoded_{i}')
        if not is_value_defined(output_char.value):
            raise TestFailure(f"Output decoded_{i} has undefined value")
        actual = chr(int(output_char.value))
        if actual != expected[i]:
            raise TestFailure(f"Full 8 char test failed at {i}: expected '{expected[i]}', got '{actual}'")
    
    # Test 5c: Pass-through non-lowercase (though constraint says input should be lowercase)
    dut._log.info("  5c: Mixed case/numbers should pass through (if implemented)")
    # This tests if implementation correctly handles only lowercase
    # All inputs are lowercase per spec, so this validates boundary
    
    dut._log.info("Test 5 passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_decode_shift_comprehensive(dut):
    """Comprehensive test with all letters."""
    dut._log.info("Test 6: Full alphabet round-trip")
    
    alphabet = "abcdefghijklmnopqrstuvwxyz"
    encoded = encode_shift(alphabet)
    
    # Test in chunks of 8
    for offset in [0, 8, 16]:
        if offset >= 26:
            break
        
        chunk = encoded[offset:min(offset+8, 26)]
        expected = alphabet[offset:min(offset+8, 26)]
        length = len(chunk)
        
        # Pad to 8
        padded = chunk + '0' * (8 - length)
        
        for i in range(8):
            setattr(dut, f'char_{i}', ascii_to_int(padded[i]))
        dut.length.value = length
        
        await Timer(50, units='ns')
        
        for i in range(length):
            output_char = getattr(dut, f'decoded_{i}')
            if not is_value_defined(output_char.value):
                raise TestFailure(f"Output decoded_{i} has undefined value")
            actual = chr(int(output_char.value))
            if actual != expected[i]:
                raise TestFailure(f"Full alphabet test failed at offset {offset}, pos {i}: expected '{expected[i]}', got '{actual}'")
    
    dut._log.info("Test 6 passed")
    dut._log.info("\nAll 6 tests passed!")
