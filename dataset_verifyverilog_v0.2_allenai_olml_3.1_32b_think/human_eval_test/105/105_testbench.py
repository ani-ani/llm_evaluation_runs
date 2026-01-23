import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

# Helper to map expected strings to bytes (5 chars, padded with spaces)
STRING_MAP = {
    1: b'One  ', 2: b'Two  ', 3: b'Three', 4: b'Four ', 5: b'Five ',
    6: b'Six  ', 7: b'Seven', 8: b'Eight', 9: b'Nine '
}

def get_bytes(val):
    return list(STRING_MAP[val])

@cocotb.test()
def test_by_length_basic(dut):
    """Test basic sorting and mapping"""
    # Test case: [2, 1, 1, 4, 5, 8, 2, 3]
    # Filtered: [2, 1, 1, 4, 5, 8, 2, 3]
    # Sorted: [1, 1, 2, 2, 3, 4, 5, 8]
    # Reversed: [8, 5, 4, 3, 2, 2, 1, 1]
    # Expected strings: Eight, Five, Four, Three, Two, Two, One, One
    
    inputs = [2, 1, 1, 4, 5, 8, 2, 3]
    
    # Set inputs
    for i in range(8):
        setattr(dut, f'arr{i}', inputs[i])
    
    await Timer(10, units='ns')
    
    # Check count
    count = int(dut.count.value)
    assert count == 8, f"Expected count 8, got {count}"
    
    # Expected result order: [8, 5, 4, 3, 2, 2, 1, 1]
    expected_ints = [8, 5, 4, 3, 2, 2, 1, 1]
    
    for i, exp_val in enumerate(expected_ints):
        for j in range(5):
            actual = getattr(dut, f'out{i}_char{j}').value
            expected = STRING_MAP[exp_val][j]
            assert actual == expected, f"Output {i} char {j}: expected {chr(expected)}, got {chr(actual)}"

@cocotb.test()
def test_by_length_empty(dut):
    """Test empty array"""
    inputs = [0, 0, 0, 0, 0, 0, 0, 0]
    
    for i in range(8):
        setattr(dut, f'arr{i}', inputs[i])
    
    await Timer(10, units='ns')
    
    count = int(dut.count.value)
    assert count == 0, f"Expected count 0, got {count}"

@cocotb.test()
def test_by_length_filtering(dut):
    """Test filtering of invalid numbers"""
    # Input: [1, -1, 55, 0, 0, 0, 0, 0]
    # Filtered: [1]
    # Sorted: [1]
    # Reversed: [1]
    inputs = [1, -1, 55, 0, 0, 0, 0, 0]
    
    for i in range(8):
        setattr(dut, f'arr{i}', inputs[i])
    
    await Timer(10, units='ns')
    
    count = int(dut.count.value)
    assert count == 1, f"Expected count 1, got {count}"
    
    # Check first output
    expected_bytes = STRING_MAP[1]
    for j in range(5):
        actual = getattr(dut, f'out0_char{j}').value
        expected = expected_bytes[j]
        assert actual == expected, f"Char {j}: expected {chr(expected)}, got {chr(actual)}"

@cocotb.test()
def test_by_length_mixed(dut):
    """Test mixed valid and invalid values"""
    # Input: [1, -1, 3, 2, 0, 0, 0, 0]
    # Filtered: [1, 3, 2]
    # Sorted: [1, 2, 3]
    # Reversed: [3, 2, 1]
    inputs = [1, -1, 3, 2, 0, 0, 0, 0]
    
    for i in range(8):
        setattr(dut, f'arr{i}', inputs[i])
    
    await Timer(10, units='ns')
    
    count = int(dut.count.value)
    assert count == 3, f"Expected count 3, got {count}"
    
    expected_ints = [3, 2, 1]
    for i, exp_val in enumerate(expected_ints):
        for j in range(5):
            actual = getattr(dut, f'out{i}_char{j}').value
            expected = STRING_MAP[exp_val][j]
            assert actual == expected, f"Output {i} char {j}: expected {chr(expected)}, got {chr(actual)}"

@cocotb.test()
def test_by_length_nine(dut):
    """Test edge case with 9"""
    # Input: [9, 4, 8, 0, 0, 0, 0, 0]
    # Filtered: [9, 4, 8]
    # Sorted: [4, 8, 9]
    # Reversed: [9, 8, 4]
    inputs = [9, 4, 8, 0, 0, 0, 0, 0]
    
    for i in range(8):
        setattr(dut, f'arr{i}', inputs[i])
    
    await Timer(10, units='ns')
    
    count = int(dut.count.value)
    assert count == 3, f"Expected count 3, got {count}"
    
    expected_ints = [9, 8, 4]
    for i, exp_val in enumerate(expected_ints):
        for j in range(5):
            actual = getattr(dut, f'out{i}_char{j}').value
            expected = STRING_MAP[exp_val][j]
            assert actual == expected, f"Output {i} char {j}: expected {chr(expected)}, got {chr(actual)}"