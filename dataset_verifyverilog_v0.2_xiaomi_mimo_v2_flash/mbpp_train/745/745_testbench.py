import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_divisible_by_digits(dut):
    """Test finding numbers divisible by their digits in range 0-15"""
    
    # Test Case 1: 1 to 15 (Python: 1,2,3,4,5,6,7,8,9,11,12,15)
    # Expected in 0-15 range: 1,2,3,4,5,6,7,8,9,11,12,15
    # Bitmask: bits 1,2,3,4,5,6,7,8,9,11,12,15 set
    dut.start_num.value = 1
    dut.end_num.value = 15
    await Timer(10, units='ns')
    
    expected_mask_1 = (1<<1) | (1<<2) | (1<<3) | (1<<4) | (1<<5) | (1<<6) | (1<<7) | (1<<8) | (1<<9) | (1<<11) | (1<<12) | (1<<15)
    actual_mask_1 = dut.valid_mask.value.integer
    
    print(f"Test 1: Range [1,15]")
    print(f"  Expected mask: {expected_mask_1:016b}")
    print(f"  Actual mask:   {actual_mask_1:016b}")
    print(f"  Expected list: [1,2,3,4,5,6,7,8,9,11,12,15]")
    print(f"  Actual list:   {[i for i in range(16) if (actual_mask_1 >> i) & 1]}")
    assert actual_mask_1 == expected_mask_1, f"Mask mismatch: expected {expected_mask_1}, got {actual_mask_1}"
    
    # Test Case 2: 1 to 9 (should include all 1-9)
    dut.start_num.value = 1
    dut.end_num.value = 9
    await Timer(10, units='ns')
    
    expected_mask_2 = 0b0000000111111110  # Bits 1-9 set
    actual_mask_2 = dut.valid_mask.value.integer
    
    print(f"
Test 2: Range [1,9]")
    print(f"  Expected mask: {expected_mask_2:016b}")
    print(f"  Actual mask:   {actual_mask_2:016b}")
    print(f"  Expected list: [1,2,3,4,5,6,7,8,9]")
    print(f"  Actual list:   {[i for i in range(16) if (actual_mask_2 >> i) & 1]}")
    assert actual_mask_2 == expected_mask_2, f"Mask mismatch: expected {expected_mask_2}, got {actual_mask_2}"
    
    # Test Case 3: 10 to 15 (Python would be empty for 10-15, but 11,12,15 are valid)
    # Note: Original Python returns [11,12,15] for 1-15, but for 10-15 it should return [11,12,15]
    dut.start_num.value = 10
    dut.end_num.value = 15
    await Timer(10, units='ns')
    
    expected_mask_3 = (1<<11) | (1<<12) | (1<<15)
    actual_mask_3 = dut.valid_mask.value.integer
    
    print(f"
Test 3: Range [10,15]")
    print(f"  Expected mask: {expected_mask_3:016b}")
    print(f"  Actual mask:   {actual_mask_3:016b}")
    print(f"  Expected list: [11,12,15]")
    print(f"  Actual list:   {[i for i in range(16) if (actual_mask_3 >> i) & 1]}")
    assert actual_mask_3 == expected_mask_3, f"Mask mismatch: expected {expected_mask_3}, got {actual_mask_3}"
    
    # Test Case 4: Edge case - numbers with 0 should be excluded
    # 10 (contains 0) should be excluded
    # 20 is out of range (max 15)
    dut.start_num.value = 0
    dut.end_num.value = 10
    await Timer(10, units='ns')
    
    # 0 is invalid (contains 0), 10 is invalid (contains 0)
    expected_mask_4 = (1<<1) | (1<<2) | (1<<3) | (1<<4) | (1<<5) | (1<<6) | (1<<7) | (1<<8) | (1<<9)
    actual_mask_4 = dut.valid_mask.value.integer
    
    print(f"
Test 4: Range [0,10] (testing 0 exclusion)")
    print(f"  Expected mask: {expected_mask_4:016b}")
    print(f"  Actual mask:   {actual_mask_4:016b}")
    print(f"  Expected list: [1,2,3,4,5,6,7,8,9]")
    print(f"  Actual list:   {[i for i in range(16) if (actual_mask_4 >> i) & 1]}")
    assert actual_mask_4 == expected_mask_4, f"Mask mismatch: expected {expected_mask_4}, got {actual_mask_4}"
    
    # Test Case 5: Verify 11 is valid (11%1==0, 11%1==0)
    # Check a range that includes 11
    dut.start_num.value = 11
    dut.end_num.value = 11
    await Timer(10, units='ns')
    
    expected_mask_5 = (1<<11)
    actual_mask_5 = dut.valid_mask.value.integer
    
    print(f"
Test 5: Range [11,11]")
    print(f"  Expected mask: {expected_mask_5:016b}")
    print(f"  Actual mask:   {actual_mask_5:016b}")
    print(f"  Expected list: [11]")
    print(f"  Actual list:   {[i for i in range(16) if (actual_mask_5 >> i) & 1]}")
    assert actual_mask_5 == expected_mask_5, f"Mask mismatch: expected {expected_mask_5}, got {actual_mask_5}"
    
    print(f"
=== All 5 tests passed! ===")