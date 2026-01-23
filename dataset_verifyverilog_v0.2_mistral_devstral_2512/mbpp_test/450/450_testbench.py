import cocotb
from cocotb.triggers import Timer
import random

# Helper function to convert Python string to 8-character byte array (null-terminated)
def str_to_bytes(s):
    # Convert string to exactly 8 bytes, null-padded
    b = s.encode('ascii')
    if len(b) > 8:
        b = b[:8]
    # Pad with zeros
    padded = b.ljust(8, b'\x00')
    return padded

# Helper to calculate expected results
def extract_expected(strings, target_len, num_strings):
    result = []
    for i in range(num_strings):
        s = strings[i]
        if len(s) == target_len:
            result.append(s)
    return result

@cocotb.test()
async def test_string_extractor(dut):
    """Test string extraction by length"""
    
    # Test cases from problem
    test_cases = [
        {
            'name': 'Test 1: len=8',
            'strings': ['Python', 'list', 'exercises', 'practice', 'solution'],
            'target_len': 8,
            'expected': ['practice', 'solution']
        },
        {
            'name': 'Test 2: len=6',
            'strings': ['Python', 'list', 'exercises', 'practice', 'solution'],
            'target_len': 6,
            'expected': ['Python']
        },
        {
            'name': 'Test 3: len=9',
            'strings': ['Python', 'list', 'exercises', 'practice', 'solution'],
            'target_len': 9,
            'expected': ['exercises']
        }
    ]
    
    print("
=== String Extractor Test Results ===")
    passed = 0
    total = len(test_cases)
    
    for tc in test_cases:
        print(f"
{tc['name']}")
        
        # Prepare inputs
        # Create 8-string array (only first 5 used)
        input_bytes = [[0]*8 for _ in range(8)]
        for i, s in enumerate(tc['strings']):
            b = str_to_bytes(s)
            for j in range(8):
                input_bytes[i][j] = b[j]
        
        # Set valid mask (5 bits for 5 strings)
        valid_mask = 0b11111
        
        # Set target length
        target_len = tc['target_len']
        
        # Drive inputs
        for i in range(8):
            for j in range(8):
                getattr(dut, f'strings_{i}_{j}').value = input_bytes[i][j]
        dut.target_len.value = target_len
        dut.valid_mask.value = valid_mask
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read outputs
        result_mask = int(dut.result_mask.value)
        result_strings = []
        
        # Decode each result entry
        for i in range(8):
            if result_mask & (1 << i):
                # Extract this string
                chars = []
                for j in range(8):
                    char_val = int(getattr(dut, f'result_{i}_{j}').value)
                    if char_val != 0:
                        chars.append(chr(char_val))
                result_strings.append(''.join(chars))
        
        # Verify
        expected = tc['expected']
        expected_mask = 0
        for i in range(8):
            if i < len(expected):
                expected_mask |= (1 << i)
        
        print(f"  Input strings: {tc['strings']}")
        print(f"  Target length: {target_len}")
        print(f"  Expected result: {expected}")
        print(f"  Got result: {result_strings}")
        print(f"  Expected mask: {bin(expected_mask)}")
        print(f"  Got mask: {bin(result_mask)}")
        
        if result_strings == expected and result_mask == expected_mask:
            print("  ✓ PASSED")
            passed += 1
        else:
            print("  ✗ FAILED")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
