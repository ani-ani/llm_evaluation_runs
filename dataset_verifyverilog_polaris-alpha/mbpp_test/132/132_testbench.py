import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_to_string(dut):
    # Test cases: (input_chars, length, expected_output)
    test_cases = [
        # Test 1: 'exercises' (9 chars)
        ([ord('e'), ord('x'), ord('e'), ord('r'), ord('c'), ord('i'), ord('s'), ord('e'), ord('s')] + [0]*7, 
         9, 
         bytes('exercises', 'ascii').ljust(16, b'\0')),
        
        # Test 2: 'python' (6 chars)
        ([ord('p'), ord('y'), ord('t'), ord('h'), ord('o'), ord('n')] + [0]*10,
         6,
         bytes('python', 'ascii').ljust(16, b'\0')),
        
        # Test 3: 'program' (7 chars)
        ([ord('p'), ord('r'), ord('o'), ord('g'), ord('r'), ord('a'), ord('m')] + [0]*9,
         7,
         bytes('program', 'ascii').ljust(16, b'\0')),
        
        # Edge case: max length (16 chars)
        ([ord('a')] * 16,
         16,
         b'a'*16)
    ]
    
    passed = 0
    for char_list, length_val, expected_bytes in test_cases:
        # Load input characters
        for i in range(16):
            dut.chars[i].value = char_list[i]
        
        dut.length.value = length_val
        await Timer(1, units='ns')
        
        # Get output as bytes object
        result_bytes = bytes([int(dut.string_out.value >> (8*(15-i)) & 0xFF) for i in range(16)])
        expected_truncated = expected_bytes[:length_val]
        result_truncated = result_bytes[:length_val]
        
        if result_truncated == expected_truncated:
            passed += 1
            dut._log.info(f"PASS: {result_truncated.decode('ascii')} == {expected_truncated.decode('ascii')}")
        else:
            msg = f"FAIL: Got {result_truncated.decode('ascii')} (0x{result_truncated.hex()}), "
            msg += f"Expected {expected_truncated.decode('ascii')} (0x{expected_truncated.hex()})"
            dut._log.error(msg)
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")