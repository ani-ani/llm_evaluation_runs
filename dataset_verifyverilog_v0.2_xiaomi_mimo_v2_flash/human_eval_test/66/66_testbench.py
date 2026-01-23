import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def char_to_ascii(c):
    """Convert character to ASCII value"""
    return ord(c) if c != ' ' else 32

def digitSum_sw(s):
    """Software reference implementation"""
    return sum(ord(c) for c in s if 'A' <= c <= 'Z')

@cocotb.test()
async def test_digitSum(dut):
    """Test digitSum module with various test cases"""
    
    # Test cases: (input_string, expected_sum)
    test_cases = [
        ("", 0),
        ("abAB", 131),
        ("abcCd", 67),
        ("helloE", 69),
        ("woArBld", 131),
        ("aAaaaXa", 153),
        (" How are yOu?", 151),
        ("You arE Very Smart", 327),
        ("AAAA", 260),  # 4 * 65
        ("zzzz", 0),    # No uppercase
        ("12345678", 0), # Numbers
        ("Z", 90),      # Single char
        ("AbCdEfG", 65+67+69+71),  # Mixed
    ]
    
    passed = 0
    total = len(test_cases)
    
    for s, expected in test_cases:
        # Pad string to 8 characters with null (0) or space (32)
        padded = s.ljust(8, ' ')[:8]
        
        # Set inputs
        dut.char0.value = char_to_ascii(padded[0])
        dut.char1.value = char_to_ascii(padded[1])
        dut.char2.value = char_to_ascii(padded[2])
        dut.char3.value = char_to_ascii(padded[3])
        dut.char4.value = char_to_ascii(padded[4])
        dut.char5.value = char_to_ascii(padded[5])
        dut.char6.value = char_to_ascii(padded[6])
        dut.char7.value = char_to_ascii(padded[7])
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        actual = int(dut.sum.value)
        
        if actual != expected:
            raise TestFailure(
                f"Test failed for input '{s}': expected {expected}, got {actual}"
            )
        
        passed += 1
        print(f"PASS: '{s}' -> {actual}")
    
    print(f"
{passed}/{total} tests passed")
