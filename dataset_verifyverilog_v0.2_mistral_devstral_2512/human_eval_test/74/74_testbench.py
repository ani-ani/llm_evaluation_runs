import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def string_to_bytes(s, max_len=8):
    """Convert string to byte array with null padding"""
    result = [0] * max_len
    for i, char in enumerate(s[:max_len]):
        result[i] = ord(char)
    return result

def get_length(s, max_len=8):
    """Get string length capped at max_len"""
    return min(len(s), max_len)

@cocotb.test()
async def test_total_match(dut):
    """Test total_match module with various test cases"""
    
    # Test case 1: Both empty
    dut.list1_valid.value = 0
    dut.list1_data.value = 0
    dut.list1_lengths.value = 0
    dut.list2_valid.value = 0
    dut.list2_data.value = 0
    dut.list2_lengths.value = 0
    await Timer(10, units='ns')
    
    result_valid = dut.result_list1_valid.value
    result_len = dut.result_list1_lengths.value
    is_first = dut.is_first_list.value
    
    # Should select list1 (tie-breaking), but valid bits should be 0
    assert result_valid == 0, f"Test 1 failed: expected valid=0, got {result_valid}"
    assert is_first == 1, f"Test 1 failed: expected is_first=1, got {is_first}"
    print("Test 1 passed: Empty lists")
    
    # Test case 2: ['hi', 'admin'] vs ['hI', 'Hi'] -> list2 wins
    # list1: 'hi' (2), 'admin' (5) -> sum = 7
    # list2: 'hI' (2), 'Hi' (2) -> sum = 4
    dut.list1_valid.value = 0b00000011  # 2 strings valid
    dut.list1_lengths.value = [2, 5, 0, 0, 0, 0, 0, 0]
    dut.list1_data[0].value = string_to_bytes('hi')
    dut.list1_data[1].value = string_to_bytes('admin')
    
    dut.list2_valid.value = 0b00000011  # 2 strings valid
    dut.list2_lengths.value = [2, 2, 0, 0, 0, 0, 0, 0]
    dut.list2_data[0].value = string_to_bytes('hI')
    dut.list2_data[1].value = string_to_bytes('Hi')
    await Timer(10, units='ns')
    
    is_first = dut.is_first_list.value
    result_valid = dut.result_list1_valid.value
    assert is_first == 0, f"Test 2 failed: expected list2 selected, got list1"
    assert result_valid == 0b00000011, f"Test 2 failed: valid bits mismatch"
    print("Test 2 passed: ['hi','admin'] vs ['hI','Hi'] -> list2")
    
    # Test case 3: ['hi', 'admin'] vs ['hi', 'hi', 'admin', 'project'] -> list1 wins
    # list1: 2 + 5 = 7
    # list2: 2 + 2 + 5 + 7 = 16
    dut.list1_valid.value = 0b00000011
    dut.list1_lengths.value = [2, 5, 0, 0, 0, 0, 0, 0]
    dut.list1_data[0].value = string_to_bytes('hi')
    dut.list1_data[1].value = string_to_bytes('admin')
    
    dut.list2_valid.value = 0b00001111
    dut.list2_lengths.value = [2, 2, 5, 7, 0, 0, 0, 0]
    dut.list2_data[0].value = string_to_bytes('hi')
    dut.list2_data[1].value = string_to_bytes('hi')
    dut.list2_data[2].value = string_to_bytes('admin')
    dut.list2_data[3].value = string_to_bytes('project')
    await Timer(10, units='ns')
    
    is_first = dut.is_first_list.value
    assert is_first == 1, f"Test 3 failed: expected list1 selected, got list2"
    print("Test 3 passed: ['hi','admin'] vs ['hi','hi','admin','project'] -> list1")
    
    # Test case 4: ['4'] vs ['1', '2', '3', '4', '5'] -> list1 wins
    # list1: 1
    # list2: 1+1+1+1+1 = 5
    dut.list1_valid.value = 0b00000001
    dut.list1_lengths.value = [1, 0, 0, 0, 0, 0, 0, 0]
    dut.list1_data[0].value = string_to_bytes('4')
    
    dut.list2_valid.value = 0b00011111
    dut.list2_lengths.value = [1, 1, 1, 1, 1, 0, 0, 0]
    dut.list2_data[0].value = string_to_bytes('1')
    dut.list2_data[1].value = string_to_bytes('2')
    dut.list2_data[2].value = string_to_bytes('3')
    dut.list2_data[3].value = string_to_bytes('4')
    dut.list2_data[4].value = string_to_bytes('5')
    await Timer(10, units='ns')
    
    is_first = dut.is_first_list.value
    assert is_first == 1, f"Test 4 failed: expected list1 selected"
    print("Test 4 passed: ['4'] vs ['1','2','3','4','5'] -> list1")
    
    # Test case 5: Tie case - ['hi', 'admin'] vs ['hI', 'hi', 'hi'] -> list1 wins (tie rule)
    # list1: 2 + 5 = 7
    # list2: 2 + 2 + 2 = 6... wait example shows list2 wins? Let me re-check
    # Wait, example shows total_match(['hi', 'admin'], ['hI', 'hi', 'hi']) == ['hI', 'hi', 'hi']
    # list2 sum = 2+2+2 = 6... but list1 = 7... so list2 wins, not tie
    # Actually check example 4 in docstring: ['hi', 'admin'] vs ['hI', 'hi', 'hii'] -> ['hi', 'admin']
    # list1: 7 chars, list2: 2+2+3 = 7 chars. Equal, so list1 wins
    
    dut.list1_valid.value = 0b00000011
    dut.list1_lengths.value = [2, 5, 0, 0, 0, 0, 0, 0]
    dut.list1_data[0].value = string_to_bytes('hi')
    dut.list1_data[1].value = string_to_bytes('admin')
    
    dut.list2_valid.value = 0b00000111
    dut.list2_lengths.value = [2, 2, 3, 0, 0, 0, 0, 0]
    dut.list2_data[0].value = string_to_bytes('hI')
    dut.list2_data[1].value = string_to_bytes('hi')
    dut.list2_data[2].value = string_to_bytes('hii')
    await Timer(10, units='ns')
    
    is_first = dut.is_first_list.value
    assert is_first == 1, f"Test 5 failed: Tie case should select list1, got list2"
    # Verify data is list1
    result_len = dut.result_list1_lengths.value
    assert result_len[0] == 2 and result_len[1] == 5, f"Test 5 failed: Wrong data returned"
    print("Test 5 passed: Tie case returns list1")
    
    # Test case 6: One empty list
    dut.list1_valid.value = 0b00000001
    dut.list1_lengths.value = [5, 0, 0, 0, 0, 0, 0, 0]
    dut.list1_data[0].value = string_to_bytes('this')
    
    dut.list2_valid.value = 0
    dut.list2_lengths.value = 0
    dut.list2_data.value = 0
    await Timer(10, units='ns')
    
    is_first = dut.is_first_list.value
    result_valid = dut.result_list1_valid.value
    # list1: 5, list2: 0. list2 wins (0 < 5)
    assert is_first == 0, f"Test 6 failed: Empty list should win"
    print("Test 6 passed: Empty list vs non-empty")
    
    print("
=== SUMMARY: All 6 tests passed! ===")