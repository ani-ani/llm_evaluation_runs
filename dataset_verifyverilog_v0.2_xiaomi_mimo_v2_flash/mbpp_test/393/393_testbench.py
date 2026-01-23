import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_max_length_list(dut):
    """Test the max_length_list module with various test cases"""
    
    # Test Case 1: Lists with lengths [1, 2, 2, 2] - max at index 1 (length 2)
    # But we want to test the adapted problem correctly
    # Given the example: [[0], [1, 3], [5, 7], [9, 11], [13, 15, 17]] with 5 lists
    # We adapt to 4 lists max, so we'll test [[0], [1, 3], [5, 7], [13, 15, 17]]
    # Lengths: 1, 2, 2, 3 -> max at index 3
    
    print("
Test 1: Lists [[0], [1,3], [5,7], [13,15,17]] - expect idx=3, length=3")
    dut.valid_mask.value = 0b1111
    # List 0: [0, 0, 0, 0] -> length 1
    dut.lists[0][0].value = 0
    dut.lists[0][1].value = 0
    dut.lists[0][2].value = 0
    dut.lists[0][3].value = 0
    # List 1: [1, 3, 0, 0] -> length 2
    dut.lists[1][0].value = 1
    dut.lists[1][1].value = 3
    dut.lists[1][2].value = 0
    dut.lists[1][3].value = 0
    # List 2: [5, 7, 0, 0] -> length 2
    dut.lists[2][0].value = 5
    dut.lists[2][1].value = 7
    dut.lists[2][2].value = 0
    dut.lists[2][3].value = 0
    # List 3: [13, 15, 17, 0] -> length 3
    dut.lists[3][0].value = 13
    dut.lists[3][1].value = 15
    dut.lists[3][2].value = 17
    dut.lists[3][3].value = 0
    
    await Timer(1, units='ns')
    
    assert dut.max_length_idx.value == 3, f"Expected idx=3, got {dut.max_length_idx.value}"
    assert dut.max_length.value == 3, f"Expected length=3, got {dut.max_length.value}"
    assert dut.max_list[0].value == 13, f"Expected max_list[0]=13"
    assert dut.max_list[1].value == 15, f"Expected max_list[1]=15"
    assert dut.max_list[2].value == 17, f"Expected max_list[2]=17"
    assert dut.max_list[3].value == 0, f"Expected max_list[3]=0"
    print("Test 1: PASSED")
    
    # Test Case 2: Lists with lengths [5, 4, 3, 2] - max at index 0
    # Adapted from: [[1,2,3,4,5],[1,2,3,4],[1,2,3],[1,2]] -> lengths [5,4,3,2]
    print("
Test 2: Lists [[1,2,3,4,5],[1,2,3,4],[1,2,3],[1,2]] - expect idx=0, length=5")
    # We can only store 4 elements, so this test is scaled down
    # Let's use [[1,2,3,4],[1,2,3],[1,2],[1]] -> lengths [4,3,2,1]
    dut.valid_mask.value = 0b1111
    # List 0: [1,2,3,4] -> length 4
    dut.lists[0][0].value = 1
    dut.lists[0][1].value = 2
    dut.lists[0][2].value = 3
    dut.lists[0][3].value = 4
    # List 1: [1,2,3,0] -> length 3
    dut.lists[1][0].value = 1
    dut.lists[1][1].value = 2
    dut.lists[1][2].value = 3
    dut.lists[1][3].value = 0
    # List 2: [1,2,0,0] -> length 2
    dut.lists[2][0].value = 1
    dut.lists[2][1].value = 2
    dut.lists[2][2].value = 0
    dut.lists[2][3].value = 0
    # List 3: [1,0,0,0] -> length 1
    dut.lists[3][0].value = 1
    dut.lists[3][1].value = 0
    dut.lists[3][2].value = 0
    dut.lists[3][3].value = 0
    
    await Timer(1, units='ns')
    
    assert dut.max_length_idx.value == 0, f"Expected idx=0, got {dut.max_length_idx.value}"
    assert dut.max_length.value == 4, f"Expected length=4, got {dut.max_length.value}"
    assert dut.max_list[0].value == 1, f"Expected max_list[0]=1"
    assert dut.max_list[1].value == 2, f"Expected max_list[1]=2"
    assert dut.max_list[2].value == 3, f"Expected max_list[2]=3"
    assert dut.max_list[3].value == 4, f"Expected max_list[3]=4"
    print("Test 2: PASSED")
    
    # Test Case 3: Lists with lengths [3, 4, 3, 0] - max at index 1
    # Adapted from: [[3,4,5],[6,7,8,9],[10,11,12]] -> lengths [3,4,3]
    print("
Test 3: Lists [[3,4,5],[6,7,8,9],[10,11,12],[]] - expect idx=1, length=4")
    dut.valid_mask.value = 0b1111
    # List 0: [3,4,5,0] -> length 3
    dut.lists[0][0].value = 3
    dut.lists[0][1].value = 4
    dut.lists[0][2].value = 5
    dut.lists[0][3].value = 0
    # List 1: [6,7,8,9] -> length 4
    dut.lists[1][0].value = 6
    dut.lists[1][1].value = 7
    dut.lists[1][2].value = 8
    dut.lists[1][3].value = 9
    # List 2: [10,11,12,0] -> length 3
    dut.lists[2][0].value = 10
    dut.lists[2][1].value = 11
    dut.lists[2][2].value = 12
    dut.lists[2][3].value = 0
    # List 3: [0,0,0,0] -> length 0
    dut.lists[3][0].value = 0
    dut.lists[3][1].value = 0
    dut.lists[3][2].value = 0
    dut.lists[3][3].value = 0
    
    await Timer(1, units='ns')
    
    assert dut.max_length_idx.value == 1, f"Expected idx=1, got {dut.max_length_idx.value}"
    assert dut.max_length.value == 4, f"Expected length=4, got {dut.max_length.value}"
    assert dut.max_list[0].value == 6, f"Expected max_list[0]=6"
    assert dut.max_list[1].value == 7, f"Expected max_list[1]=7"
    assert dut.max_list[2].value == 8, f"Expected max_list[2]=8"
    assert dut.max_list[3].value == 9, f"Expected max_list[3]=9"
    print("Test 3: PASSED")
    
    # Test Case 4: Edge case - all lists have same length (tie)
    # Should return the first one (index 0)
    print("
Test 4: All lists length 2 - expect idx=0, length=2")
    dut.valid_mask.value = 0b1111
    for i in range(4):
        dut.lists[i][0].value = i * 10 + 1
        dut.lists[i][1].value = i * 10 + 2
        dut.lists[i][2].value = 0
        dut.lists[i][3].value = 0
    
    await Timer(1, units='ns')
    
    assert dut.max_length_idx.value == 0, f"Expected idx=0 (tie-breaker), got {dut.max_length_idx.value}"
    assert dut.max_length.value == 2, f"Expected length=2, got {dut.max_length.value}"
    print("Test 4: PASSED")
    
    # Test Case 5: Valid mask selects only some lists
    print("
Test 5: Valid mask 0b1010 (lists 1 and 3 only), lengths [2,4] - expect idx=3, length=4")
    dut.valid_mask.value = 0b1010
    # List 0: irrelevant
    dut.lists[0][0].value = 99
    # List 1: [10,20,0,0] -> length 2
    dut.lists[1][0].value = 10
    dut.lists[1][1].value = 20
    dut.lists[1][2].value = 0
    dut.lists[1][3].value = 0
    # List 2: irrelevant
    dut.lists[2][0].value = 99
    # List 3: [30,40,50,60] -> length 4
    dut.lists[3][0].value = 30
    dut.lists[3][1].value = 40
    dut.lists[3][2].value = 50
    dut.lists[3][3].value = 60
    
    await Timer(1, units='ns')
    
    assert dut.max_length_idx.value == 3, f"Expected idx=3, got {dut.max_length_idx.value}"
    assert dut.max_length.value == 4, f"Expected length=4, got {dut.max_length.value}"
    assert dut.max_list[0].value == 30, f"Expected max_list[0]=30"
    assert dut.max_list[1].value == 40, f"Expected max_list[1]=40"
    assert dut.max_list[2].value == 50, f"Expected max_list[2]=50"
    assert dut.max_list[3].value == 60, f"Expected max_list[3]=60"
    print("Test 5: PASSED")
    
    print("
=== All 5 tests passed! ===")
    print("Summary: 5/5 tests passed")