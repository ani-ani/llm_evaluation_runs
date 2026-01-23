import cocotb
from cocotb.triggers import Timer

# Map subjects to 8-bit tags
subject_map = {
    'English': 0, 'Science': 1, 'Maths': 2, 'Social sciences': 3,
    'Telugu': 4, 'Hindhi': 5, 'Social': 6,
    'Physics': 7, 'Chemistry': 8, 'Biology': 9
}

def encode_tuple(subject, value):
    """Encode (subject, value) as 16-bit: [tag:8][value:8]"""
    tag = subject_map[subject]
    return (value << 8) | tag

def decode_tuple(encoded):
    """Decode 16-bit back to (tag, value) tuple"""
    tag = encoded & 0xFF
    value = (encoded >> 8) & 0xFF
    # Find subject name
    for name, id in subject_map.items():
        if id == tag:
            return (name, value)
    return ("Unknown", value)

def python_sort(tuples):
    """Original Python sort function for reference"""
    return sorted(tuples, key=lambda x: x[1])

@cocotb.test()
async def test_sort_tuples(dut):
    """Test sorting of tuple lists based on second value"""
    
    # Test cases from original problem
    test_cases = [
        {
            'name': 'Test 1: English, Science, Maths, Social sciences',
            'input': [('English', 88), ('Science', 90), ('Maths', 97), ('Social sciences', 82)],
            'expected': [('Social sciences', 82), ('English', 88), ('Science', 90), ('Maths', 97)]
        },
        {
            'name': 'Test 2: Telugu, Hindhi, Social',
            'input': [('Telugu', 49), ('Hindhi', 54), ('Social', 33)],
            'expected': [('Social', 33), ('Telugu', 49), ('Hindhi', 54)]
        },
        {
            'name': 'Test 3: Physics, Chemistry, Biology',
            'input': [('Physics', 96), ('Chemistry', 97), ('Biology', 45)],
            'expected': [('Biology', 45), ('Physics', 96), ('Chemistry', 97)]
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test in test_cases:
        print(f"
Running {test['name']}...")
        
        # Pad input to 4 elements with dummy tuples (value 0) if needed
        input_list = test['input'].copy()
        while len(input_list) < 4:
            input_list.append(('Dummy', 0))
        
        # Encode input tuples
        dut.tuple_0.value = encode_tuple(input_list[0][0], input_list[0][1])
        dut.tuple_1.value = encode_tuple(input_list[1][0], input_list[1][1])
        dut.tuple_2.value = encode_tuple(input_list[2][0], input_list[2][1])
        dut.tuple_3.value = encode_tuple(input_list[3][0], input_list[3][1])
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read outputs
        out_0 = int(dut.sorted_0.value)
        out_1 = int(dut.sorted_1.value)
        out_2 = int(dut.sorted_2.value)
        out_3 = int(dut.sorted_3.value)
        
        # Decode outputs
        result = []
        for out_val in [out_0, out_1, out_2, out_3]:
            name, score = decode_tuple(out_val)
            if name != 'Dummy':
                result.append((name, score))
        
        # Get expected output (remove padded dummies if any)
        expected = test['expected']
        
        # Verify
        print(f"  Input:  {test['input']}")
        print(f"  Result: {result}")
        print(f"  Expected: {expected}")
        
        # Check length first
        if len(result) != len(expected):
            print(f"  FAIL: Length mismatch (got {len(result)}, expected {len(expected)})")
            continue
        
        # Check each tuple
        match = True
        for i, (exp, got) in enumerate(zip(expected, result)):
            if exp != got:
                print(f"  FAIL: Position {i} - expected {exp}, got {got}")
                match = False
                break
        
        if match:
            print("  PASS")
            passed += 1
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Expected all {total} tests to pass, but only {passed} passed"