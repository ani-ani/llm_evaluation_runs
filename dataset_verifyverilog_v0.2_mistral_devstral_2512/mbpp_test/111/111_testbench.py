import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_common_in_nested_lists(dut):
    """Test common elements in three nested lists"""
    
    # Test case 1: Original example from Python problem
    # List1: [12, 18, 23, 25, 45], List2: [7, 12, 18, 24, 28], List3: [1, 5, 8, 12, 15, 16, 18]
    # Expected: [12, 18] (order: 18 first, then 12 based on packing)
    dut.list1[0].value = 12
    dut.list1[1].value = 18
    dut.list1[2].value = 23
    dut.list1[3].value = 25
    dut.list1[4].value = 45
    dut.list1[5].value = 0
    dut.list1[6].value = 0
    dut.list1[7].value = 0
    
    dut.list2[0].value = 7
    dut.list2[1].value = 12
    dut.list2[2].value = 18
    dut.list2[3].value = 24
    dut.list2[4].value = 28
    dut.list2[5].value = 0
    dut.list2[6].value = 0
    dut.list2[7].value = 0
    
    dut.list3[0].value = 1
    dut.list3[1].value = 5
    dut.list3[2].value = 8
    dut.list3[3].value = 12
    dut.list3[4].value = 15
    dut.list3[5].value = 16
    dut.list3[6].value = 18
    dut.list3[7].value = 0
    
    await Timer(10, units='ns')
    
    # Check results - should find 12 and 18 as common
    common = []
    for i in range(8):
        elem = (dut.common_elements.value >> (i*8)) & 0xFF
        if elem != 0:
            common.append(elem)
    
    count = int(dut.count.value)
    print(f"Test 1: Found {count} common elements: {common}")
    assert count == 2, f"Expected 2 common elements, got {count}"
    assert set(common) == {12, 18}, f"Expected {{12, 18}}, got {set(common)}"
    
    # Test case 2
    dut.list1[0].value = 12
    dut.list1[1].value = 5
    dut.list1[2].value = 23
    dut.list1[3].value = 25
    dut.list1[4].value = 45
    dut.list1[5].value = 0
    dut.list1[6].value = 0
    dut.list1[7].value = 0
    
    dut.list2[0].value = 7
    dut.list2[1].value = 11
    dut.list2[2].value = 5
    dut.list2[3].value = 23
    dut.list2[4].value = 28
    dut.list2[5].value = 0
    dut.list2[6].value = 0
    dut.list2[7].value = 0
    
    dut.list3[0].value = 1
    dut.list3[1].value = 5
    dut.list3[2].value = 8
    dut.list3[3].value = 18
    dut.list3[4].value = 23
    dut.list3[5].value = 16
    dut.list3[6].value = 0
    dut.list3[7].value = 0
    
    await Timer(10, units='ns')
    
    common = []
    for i in range(8):
        elem = (dut.common_elements.value >> (i*8)) & 0xFF
        if elem != 0:
            common.append(elem)
    
    count = int(dut.count.value)
    print(f"Test 2: Found {count} common elements: {common}")
    assert count == 2, f"Expected 2 common elements, got {count}"
    assert set(common) == {5, 23}, f"Expected {{5, 23}}, got {set(common)}"
    
    # Test case 3
    dut.list1[0].value = 2
    dut.list1[1].value = 3
    dut.list1[2].value = 4
    dut.list1[3].value = 1
    dut.list1[4].value = 0
    dut.list1[5].value = 0
    dut.list1[6].value = 0
    dut.list1[7].value = 0
    
    dut.list2[0].value = 4
    dut.list2[1].value = 5
    dut.list2[2].value = 0
    dut.list2[3].value = 0
    dut.list2[4].value = 0
    dut.list2[5].value = 0
    dut.list2[6].value = 0
    dut.list2[7].value = 0
    
    dut.list3[0].value = 6
    dut.list3[1].value = 4
    dut.list3[2].value = 8
    dut.list3[3].value = 0
    dut.list3[4].value = 0
    dut.list3[5].value = 0
    dut.list3[6].value = 0
    dut.list3[7].value = 0
    
    await Timer(10, units='ns')
    
    common = []
    for i in range(8):
        elem = (dut.common_elements.value >> (i*8)) & 0xFF
        if elem != 0:
            common.append(elem)
    
    count = int(dut.count.value)
    print(f"Test 3: Found {count} common elements: {common}")
    assert count == 1, f"Expected 1 common element, got {count}"
    assert set(common) == {4}, f"Expected {{4}}, got {set(common)}"
    
    # Test case 4: No common elements
    dut.list1[0].value = 1
    dut.list1[1].value = 2
    dut.list1[2].value = 3
    dut.list1[3].value = 4
    dut.list1[4].value = 0
    dut.list1[5].value = 0
    dut.list1[6].value = 0
    dut.list1[7].value = 0
    
    dut.list2[0].value = 5
    dut.list2[1].value = 6
    dut.list2[2].value = 7
    dut.list2[3].value = 8
    dut.list2[4].value = 0
    dut.list2[5].value = 0
    dut.list2[6].value = 0
    dut.list2[7].value = 0
    
    dut.list3[0].value = 9
    dut.list3[1].value = 10
    dut.list3[2].value = 11
    dut.list3[3].value = 12
    dut.list3[4].value = 0
    dut.list3[5].value = 0
    dut.list3[6].value = 0
    dut.list3[7].value = 0
    
    await Timer(10, units='ns')
    
    common = []
    for i in range(8):
        elem = (dut.common_elements.value >> (i*8)) & 0xFF
        if elem != 0:
            common.append(elem)
    
    count = int(dut.count.value)
    print(f"Test 4: Found {count} common elements: {common}")
    assert count == 0, f"Expected 0 common elements, got {count}"
    assert len(common) == 0, f"Expected empty set, got {common}"
    
    # Test case 5: All elements common
    dut.list1[0].value = 10
    dut.list1[1].value = 20
    dut.list1[2].value = 30
    dut.list1[3].value = 40
    dut.list1[4].value = 0
    dut.list1[5].value = 0
    dut.list1[6].value = 0
    dut.list1[7].value = 0
    
    dut.list2[0].value = 10
    dut.list2[1].value = 20
    dut.list2[2].value = 30
    dut.list2[3].value = 40
    dut.list2[4].value = 0
    dut.list2[5].value = 0
    dut.list2[6].value = 0
    dut.list2[7].value = 0
    
    dut.list3[0].value = 10
    dut.list3[1].value = 20
    dut.list3[2].value = 30
    dut.list3[3].value = 40
    dut.list3[4].value = 0
    dut.list3[5].value = 0
    dut.list3[6].value = 0
    dut.list3[7].value = 0
    
    await Timer(10, units='ns')
    
    common = []
    for i in range(8):
        elem = (dut.common_elements.value >> (i*8)) & 0xFF
        if elem != 0:
            common.append(elem)
    
    count = int(dut.count.value)
    print(f"Test 5: Found {count} common elements: {common}")
    assert count == 4, f"Expected 4 common elements, got {count}"
    assert set(common) == {10, 20, 30, 40}, f"Expected {{10, 20, 30, 40}}, got {set(common)}"
    
    print(f"
All tests passed! Total: 5/5")