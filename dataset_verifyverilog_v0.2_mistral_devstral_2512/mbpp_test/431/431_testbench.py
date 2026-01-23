import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_common_element(dut):
    """Test common_element module for finding common elements between two arrays"""
    
    # Test case 1: Arrays with common element 5
    dut.list1[0] = 1
    dut.list1[1] = 2
    dut.list1[2] = 3
    dut.list1[3] = 4
    dut.list1[4] = 5
    
    dut.list2[0] = 5
    dut.list2[1] = 6
    dut.list2[2] = 7
    dut.list2[3] = 8
    dut.list2[4] = 9
    
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 1 failed: Expected result=1 (common element 5), got {dut.result.value}"
    print("Test 1 passed: [1,2,3,4,5] and [5,6,7,8,9] share element 5")
    
    # Test case 2: No common elements
    dut.list1[0] = 1
    dut.list1[1] = 2
    dut.list1[2] = 3
    dut.list1[3] = 4
    dut.list1[4] = 5
    
    dut.list2[0] = 6
    dut.list2[1] = 7
    dut.list2[2] = 8
    dut.list2[3] = 9
    dut.list2[4] = 10
    
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 2 failed: Expected result=0 (no common elements), got {dut.result.value}"
    print("Test 2 passed: [1,2,3,4,5] and [6,7,8,9,10] share no elements")
    
    # Test case 3: Character arrays with common element 'b' (ASCII 0x62)
    dut.list1[0] = ord('a')  # 0x61
    dut.list1[1] = ord('b')  # 0x62
    dut.list1[2] = ord('c')  # 0x63
    dut.list1[3] = 0
    dut.list1[4] = 0
    
    dut.list2[0] = ord('d')  # 0x64
    dut.list2[1] = ord('b')  # 0x62
    dut.list2[2] = ord('e')  # 0x65
    dut.list2[3] = 0
    dut.list2[4] = 0
    
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 3 failed: Expected result=1 (common element 'b'), got {dut.result.value}"
    print("Test 3 passed: ['a','b','c'] and ['d','b','e'] share element 'b'")
    
    # Test case 4: Edge case - first element matches
    dut.list1[0] = 42
    dut.list1[1] = 0
    dut.list1[2] = 0
    dut.list1[3] = 0
    dut.list1[4] = 0
    
    dut.list2[0] = 42
    dut.list2[1] = 100
    dut.list2[2] = 200
    dut.list2[3] = 255
    dut.list2[4] = 1
    
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 4 failed: Expected result=1 (common element 42), got {dut.result.value}"
    print("Test 4 passed: Edge case - first element matches")
    
    # Test case 5: Edge case - last element matches
    dut.list1[0] = 10
    dut.list1[1] = 20
    dut.list1[2] = 30
    dut.list1[3] = 40
    dut.list1[4] = 50
    
    dut.list2[0] = 15
    dut.list2[1] = 25
    dut.list2[2] = 35
    dut.list2[3] = 45
    dut.list2[4] = 50
    
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 5 failed: Expected result=1 (common element 50), got {dut.result.value}"
    print("Test 5 passed: Edge case - last element matches")
    
    # Test case 6: Both arrays identical
    dut.list1[0] = 1
    dut.list1[1] = 2
    dut.list1[2] = 3
    dut.list1[3] = 4
    dut.list1[4] = 5
    
    dut.list2[0] = 1
    dut.list2[1] = 2
    dut.list2[2] = 3
    dut.list2[3] = 4
    dut.list2[4] = 5
    
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 6 failed: Expected result=1 (all elements common), got {dut.result.value}"
    print("Test 6 passed: Both arrays identical")
    
    print("
All 6/6 tests passed!")