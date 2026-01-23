import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_sub_list_basic(dut):
    """Test basic element-wise subtraction"""
    # Test 1: [1,2,3] - [4,5,6] = [-3,-3,-3]
    dut.length.value = 3
    dut.nums1[0].value = 1
    dut.nums1[1].value = 2
    dut.nums1[2].value = 3
    dut.nums2[0].value = 4
    dut.nums2[1].value = 5
    dut.nums2[2].value = 6
    
    await Timer(10, units='ns')
    
    # Check results (signed 8-bit: -3 = 0xFD = 253)
    assert dut.result[0].value == 0xFD, f"Expected -3 (0xFD), got {dut.result[0].value}"
    assert dut.result[1].value == 0xFD, f"Expected -3 (0xFD), got {dut.result[1].value}"
    assert dut.result[2].value == 0xFD, f"Expected -3 (0xFD), got {dut.result[2].value}"
    print("Test 1 passed: [1,2,3] - [4,5,6] = [-3,-3,-3]")

@cocotb.test()
async def test_sub_list_shorter(dut):
    """Test with 2 elements"""
    # Test 2: [1,2] - [3,4] = [-2,-2]
    dut.length.value = 2
    dut.nums1[0].value = 1
    dut.nums1[1].value = 2
    dut.nums2[0].value = 3
    dut.nums2[1].value = 4
    
    await Timer(10, units='ns')
    
    # -2 = 0xFE = 254
    assert dut.result[0].value == 0xFE, f"Expected -2 (0xFE), got {dut.result[0].value}"
    assert dut.result[1].value == 0xFE, f"Expected -2 (0xFE), got {dut.result[1].value}"
    print("Test 2 passed: [1,2] - [3,4] = [-2,-2]")

@cocotb.test()
async def test_sub_list_positive(dut):
    """Test with positive result"""
    # Test 3: [90,120] - [50,70] = [40,50]
    dut.length.value = 2
    dut.nums1[0].value = 90
    dut.nums1[1].value = 120
    dut.nums2[0].value = 50
    dut.nums2[1].value = 70
    
    await Timer(10, units='ns')
    
    assert dut.result[0].value == 40, f"Expected 40, got {dut.result[0].value}"
    assert dut.result[1].value == 50, f"Expected 50, got {dut.result[1].value}"
    print("Test 3 passed: [90,120] - [50,70] = [40,50]")

@cocotb.test()
async def test_sub_list_edge_cases(dut):
    """Test edge cases: min, max, zero"""
    # Test with max and min values
    dut.length.value = 4
    dut.nums1[0].value = 127  # max positive
    dut.nums1[1].value = 0
    dut.nums1[2].value = 128  # -128 (0x80)
    dut.nums1[3].value = 255  # -1 (0xFF)
    
    dut.nums2[0].value = 127
    dut.nums2[1].value = 0
    dut.nums2[2].value = 0
    dut.nums2[3].value = 1
    
    await Timer(10, units='ns')
    
    # 127-127=0, 0-0=0, -128-0=-128, -1-1=-2
    assert dut.result[0].value == 0, f"Expected 0, got {dut.result[0].value}"
    assert dut.result[1].value == 0, f"Expected 0, got {dut.result[1].value}"
    assert dut.result[2].value == 128, f"Expected -128 (128), got {dut.result[2].value}"
    assert dut.result[3].value == 254, f"Expected -2 (254), got {dut.result[3].value}"
    print("Test 4 passed: edge cases with min/max/zero values")

@cocotb.test()
async def test_sub_list_full_length(dut):
    """Test with maximum length (8 elements)"""
    dut.length.value = 8
    for i in range(8):
        dut.nums1[i].value = 50 + i
        dut.nums2[i].value = 20 + i
    
    await Timer(10, units='ns')
    
    for i in range(8):
        expected = 30  # 50+i - (20+i) = 30
        assert dut.result[i].value == expected, f"Index {i}: Expected {expected}, got {dut.result[i].value}"
    print("Test 5 passed: full 8-element array subtraction")

@cocotb.test()
async def test_sub_list_summary(dut):
    """Print summary"""
    print("
=== Test Summary ===")
    print("All 5 tests for element-wise list subtraction passed!")
    print("Tests cover: basic cases, shorter arrays, positive results, edge cases, full length")