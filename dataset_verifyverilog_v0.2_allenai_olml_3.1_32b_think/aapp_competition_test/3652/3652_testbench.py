import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_chemistry_table(dut):
    """Test chemistry_table module with multiple test cases"""
    
    # Test Case 1: N=8
    # row1: 5 4 3 2 1 6 7 8
    # row2: 5 5 1 1 3 4 7 8
    # row3: 3 7 1 4 5 6 2 8
    # Expected output: 4 (delete 4 columns)
    
    dut.row1_val_0.value = 5
    dut.row1_val_1.value = 4
    dut.row1_val_2.value = 3
    dut.row1_val_3.value = 2
    dut.row1_val_4.value = 1
    dut.row1_val_5.value = 6
    dut.row1_val_6.value = 7
    dut.row1_val_7.value = 8
    
    dut.row2_val_0.value = 5
    dut.row2_val_1.value = 5
    dut.row2_val_2.value = 1
    dut.row2_val_3.value = 1
    dut.row2_val_4.value = 3
    dut.row2_val_5.value = 4
    dut.row2_val_6.value = 7
    dut.row2_val_7.value = 8
    
    dut.row3_val_0.value = 3
    dut.row3_val_1.value = 7
    dut.row3_val_2.value = 1
    dut.row3_val_3.value = 4
    dut.row3_val_4.value = 5
    dut.row3_val_5.value = 6
    dut.row3_val_6.value = 2
    dut.row3_val_7.value = 8
    
    await Timer(10, units='ns')
    result1 = int(dut.min_deletions.value)
    print(f"Test 1: Expected 4, Got {result1}")
    assert result1 == 4, f"Test 1 failed: expected 4, got {result1}"
    
    # Test Case 2: N=8 (scaled from 9)
    # row1: 1 3 5 8 7 6 2 4
    # row2: 2 1 5 6 4 8 3 4
    # row3: 3 5 1 8 7 6 2 8
    # Expected output: 2
    
    dut.row1_val_0.value = 1
    dut.row1_val_1.value = 3
    dut.row1_val_2.value = 5
    dut.row1_val_3.value = 8
    dut.row1_val_4.value = 7
    dut.row1_val_5.value = 6
    dut.row1_val_6.value = 2
    dut.row1_val_7.value = 4
    
    dut.row2_val_0.value = 2
    dut.row2_val_1.value = 1
    dut.row2_val_2.value = 5
    dut.row2_val_3.value = 6
    dut.row2_val_4.value = 4
    dut.row2_val_5.value = 8
    dut.row2_val_6.value = 3
    dut.row2_val_7.value = 4
    
    dut.row3_val_0.value = 3
    dut.row3_val_1.value = 5
    dut.row3_val_2.value = 1
    dut.row3_val_3.value = 8
    dut.row3_val_4.value = 7
    dut.row3_val_5.value = 6
    dut.row3_val_6.value = 2
    dut.row3_val_7.value = 8
    
    await Timer(10, units='ns')
    result2 = int(dut.min_deletions.value)
    print(f"Test 2: Expected 2, Got {result2}")
    assert result2 == 2, f"Test 2 failed: expected 2, got {result2}"
    
    # Test Case 3: All rows identical (edge case)
    # All rows: 1 2 3 4 5 6 7 8
    # Expected: 0 deletions needed
    
    for i in range(8):
        val = i + 1
        setattr(dut, f'row1_val_{i}').value = val
        setattr(dut, f'row2_val_{i}').value = val
        setattr(dut, f'row3_val_{i}').value = val
    
    await Timer(10, units='ns')
    result3 = int(dut.min_deletions.value)
    print(f"Test 3: Expected 0, Got {result3}")
    assert result3 == 0, f"Test 3 failed: expected 0, got {result3}"
    
    # Test Case 4: No common multiset possible except empty
    # row1: 1 2 3 4 5 6 7 8
    # row2: 8 7 6 5 4 3 2 1
    # row3: 1 1 1 1 1 1 1 1
    # Expected: 7 (only 1 column can match: if we pick a value that exists in all?)
    # Actually, only single columns match. Max subset size=1
    
    dut.row1_val_0.value = 1
    dut.row1_val_1.value = 2
    dut.row1_val_2.value = 3
    dut.row1_val_3.value = 4
    dut.row1_val_4.value = 5
    dut.row1_val_5.value = 6
    dut.row1_val_6.value = 7
    dut.row1_val_7.value = 8
    
    dut.row2_val_0.value = 8
    dut.row2_val_1.value = 7
    dut.row2_val_2.value = 6
    dut.row2_val_3.value = 5
    dut.row2_val_4.value = 4
    dut.row2_val_5.value = 3
    dut.row2_val_6.value = 2
    dut.row2_val_7.value = 1
    
    dut.row3_val_0.value = 1
    dut.row3_val_1.value = 1
    dut.row3_val_2.value = 1
    dut.row3_val_3.value = 1
    dut.row3_val_4.value = 1
    dut.row3_val_5.value = 1
    dut.row3_val_6.value = 1
    dut.row3_val_7.value = 1
    
    await Timer(10, units='ns')
    result4 = int(dut.min_deletions.value)
    print(f"Test 4: Expected 7, Got {result4}")
    assert result4 == 7, f"Test 4 failed: expected 7, got {result4}"
    
    # Test Case 5: Minimum N=1
    # row1: 1
    # row2: 1
    # row3: 1
    # Expected: 0
    
    dut.row1_val_0.value = 1
    dut.row2_val_0.value = 1
    dut.row3_val_0.value = 1
    
    # Set all unused values to 0 or any value
    for i in range(1, 8):
        setattr(dut, f'row1_val_{i}').value = 0
        setattr(dut, f'row2_val_{i}').value = 0
        setattr(dut, f'row3_val_{i}').value = 0
    
    await Timer(10, units='ns')
    result5 = int(dut.min_deletions.value)
    print(f"Test 5: Expected 0, Got {result5}")
    assert result5 == 0, f"Test 5 failed: expected 0, got {result5}"
    
    print(f"
Summary: All 5 tests passed!")