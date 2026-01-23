import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def to_hex(value):
    return hex(value)

@cocotb.test()
async def test_sublist_checker(dut):
    """Test sublist checker with various cases"""
    
    # Test Case 1: Sublist [4,3] exists in [2,4,3,5,7,0,0,0] at position 1
    dut.main_list[0].value = 2
    dut.main_list[1].value = 4
    dut.main_list[2].value = 3
    dut.main_list[3].value = 5
    dut.main_list[4].value = 7
    dut.main_list[5].value = 0
    dut.main_list[6].value = 0
    dut.main_list[7].value = 0
    
    dut.sub_list[0].value = 4
    dut.sub_list[1].value = 3
    dut.sub_list[2].value = 0
    dut.sub_list[3].value = 0
    dut.sub_len.value = 2
    
    await Timer(10, units='ns')
    
    if dut.is_sublist.value != 1:
        raise TestFailure(f"Test 1 failed: Expected is_sublist=1, got {dut.is_sublist.value}")
    print(f"Test 1 passed: [4,3] found in [2,4,3,5,7]")
    
    # Test Case 2: Sublist [3,7] should NOT exist (3 at pos 2, 7 at pos 4 - not contiguous)
    dut.sub_list[0].value = 3
    dut.sub_list[1].value = 7
    dut.sub_len.value = 2
    
    await Timer(10, units='ns')
    
    if dut.is_sublist.value != 0:
        raise TestFailure(f"Test 2 failed: Expected is_sublist=0, got {dut.is_sublist.value}")
    print(f"Test 2 passed: [3,7] not found in [2,4,3,5,7]")
    
    # Test Case 3: Sublist [1,6] does not exist
    dut.sub_list[0].value = 1
    dut.sub_list[1].value = 6
    dut.sub_len.value = 2
    
    await Timer(10, units='ns')
    
    if dut.is_sublist.value != 0:
        raise TestFailure(f"Test 3 failed: Expected is_sublist=0, got {dut.is_sublist.value}")
    print(f"Test 3 passed: [1,6] not found in [2,4,3,5,7]")
    
    # Test Case 4: Empty sublist should always return true
    dut.sub_len.value = 0
    
    await Timer(10, units='ns')
    
    if dut.is_sublist.value != 1:
        raise TestFailure(f"Test 4 failed: Empty sublist should return 1, got {dut.is_sublist.value}")
    print(f"Test 4 passed: Empty sublist detected")
    
    # Test Case 5: Full match - sub_list equals main_list prefix
    dut.sub_list[0].value = 2
    dut.sub_list[1].value = 4
    dut.sub_list[2].value = 3
    dut.sub_list[3].value = 5
    dut.sub_len.value = 4
    
    await Timer(10, units='ns')
    
    if dut.is_sublist.value != 1:
        raise TestFailure(f"Test 5 failed: Expected is_sublist=1, got {dut.is_sublist.value}")
    print(f"Test 5 passed: [2,4,3,5] found at position 0")
    
    # Test Case 6: Sublist at the end
    dut.main_list[0].value = 2
    dut.main_list[1].value = 4
    dut.main_list[2].value = 3
    dut.main_list[3].value = 5
    dut.main_list[4].value = 7
    dut.main_list[5].value = 7
    dut.main_list[6].value = 8
    dut.main_list[7].value = 9
    
    dut.sub_list[0].value = 7
    dut.sub_list[1].value = 8
    dut.sub_len.value = 2
    
    await Timer(10, units='ns')
    
    if dut.is_sublist.value != 1:
        raise TestFailure(f"Test 6 failed: Expected is_sublist=1, got {dut.is_sublist.value}")
    print(f"Test 6 passed: [7,8] found at position 6")
    
    print(f"
Results: All 6 tests passed!")
}