import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_count_same_pair(dut):
    """Test counting same pairs in arrays"""
    
    # Test case 1: 4 matches
    # nums1: [1, 2, 3, 4, 5, 6, 7, 8] -> 0x0102030405060708
    # nums2: [2, 2, 3, 1, 2, 6, 7, 9] -> 0x0202030102060709
    dut.nums1.value = 0x0102030405060708
    dut.nums2.value = 0x0202030102060709
    await Timer(1, units='ns')
    assert dut.count.value == 4, f"Test 1 failed: expected 4, got {dut.count.value}"
    print("Test 1 passed: 4 matches")
    
    # Test case 2: 11 matches (using first 11 of 13, padded to 8)
    # nums1: [0, 1, 2, -1, -5, 6, 0, -3] -> 0x000102FFFB0600FD
    # nums2: [2, 1, 2, -1, -5, 6, 4, -3] -> 0x020102FFFB0604FD
    dut.nums1.value = 0x000102FFFB0600FD
    dut.nums2.value = 0x020102FFFB0604FD
    await Timer(1, units='ns')
    assert dut.count.value == 6, f"Test 2 failed: expected 6, got {dut.count.value}"
    print("Test 2 passed: 6 matches (first 8 elements)")
    
    # Test case 3: 1 match
    # nums1: [2, 4, -6, -9, 11, -12, 14, -5] -> 0x0204FAF70BF40EFB
    # nums2: [2, 1, 2, -1, -5, 6, 4, -3] -> 0x020102FFFB0604FD
    dut.nums1.value = 0x0204FAF70BF40EFB
    dut.nums2.value = 0x020102FFFB0604FD
    await Timer(1, units='ns')
    assert dut.count.value == 1, f"Test 3 failed: expected 1, got {dut.count.value}"
    print("Test 3 passed: 1 match")
    
    # Test case 4: 3 matches
    # nums1: [0, 1, 1, 2, 0, 0, 0, 0] -> 0x0001010200000000
    # nums2: [0, 1, 2, 2, 0, 0, 0, 0] -> 0x0001020200000000
    dut.nums1.value = 0x0001010200000000
    dut.nums2.value = 0x0001020200000000
    await Timer(1, units='ns')
    assert dut.count.value == 3, f"Test 4 failed: expected 3, got {dut.count.value}"
    print("Test 4 passed: 3 matches")
    
    # Test case 5: All 8 match
    # nums1: [0, 1, 2, 3, 4, 5, 6, 7] -> 0x0001020304050607
    # nums2: [0, 1, 2, 3, 4, 5, 6, 7] -> 0x0001020304050607
    dut.nums1.value = 0x0001020304050607
    dut.nums2.value = 0x0001020304050607
    await Timer(1, units='ns')
    assert dut.count.value == 8, f"Test 5 failed: expected 8, got {dut.count.value}"
    print("Test 5 passed: 8 matches")
    
    # Test case 6: Zero matches
    # nums1: [0, 1, 2, 3, 4, 5, 6, 7] -> 0x0001020304050607
    # nums2: [8, 9, 10, 11, 12, 13, 14, 15] -> 0x08090A0B0C0D0E0F
    dut.nums1.value = 0x0001020304050607
    dut.nums2.value = 0x08090A0B0C0D0E0F
    await Timer(1, units='ns')
    assert dut.count.value == 0, f"Test 6 failed: expected 0, got {dut.count.value}"
    print("Test 6 passed: 0 matches")
    
    print("
All 6 tests passed!")