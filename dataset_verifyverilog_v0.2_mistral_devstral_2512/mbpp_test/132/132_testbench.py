import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to convert string to expected 64-bit value
def string_to_64bit(s):
    result = 0
    for i, char in enumerate(s):
        result |= (ord(char) << (56 - i*8))
    return result

@cocotb.test()
async def test_tuple_to_string(dut):
    """Test tuple to string conversion"""
    
    # Test case 1: "exercises" (9 chars) - but we only support up to 8
    # Let's test with "exercise" (8 chars) and "exercises" truncated
    
    test_cases = [
        ("exercise", [ord('e'), ord('x'), ord('e'), ord('r'), ord('c'), ord('i'), ord('s'), ord('e')], 8),
        ("python",   [ord('p'), ord('y'), ord('t'), ord('h'), ord('o'), ord('n'), 0, 0], 6),
        ("program",  [ord('p'), ord('r'), ord('o'), ord('g'), ord('r'), ord('a'), ord('m'), 0], 7),
        ("a",        [ord('a'), 0, 0, 0, 0, 0, 0, 0], 1),
        ("",         [0, 0, 0, 0, 0, 0, 0, 0], 0),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for expected_str, chars, length in test_cases:
        # Set inputs
        dut.char_0.value = chars[0]
        dut.char_1.value = chars[1]
        dut.char_2.value = chars[2]
        dut.char_3.value = chars[3]
        dut.char_4.value = chars[4]
        dut.char_5.value = chars[5]
        dut.char_6.value = chars[6]
        dut.char_7.value = chars[7]
        dut.length.value = length
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Get actual result
        actual = int(dut.result.value)
        expected = string_to_64bit(expected_str)
        
        if actual == expected:
            passed += 1
            dut._log.info(f"Test '{expected_str}': PASS (0x{actual:016x})")
        else:
            dut._log.error(f"Test '{expected_str}': FAIL")
            dut._log.error(f"  Expected: 0x{expected:016x}")
            dut._log.error(f"  Actual:   0x{actual:016x}")
    
    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"{total - passed} tests failed")