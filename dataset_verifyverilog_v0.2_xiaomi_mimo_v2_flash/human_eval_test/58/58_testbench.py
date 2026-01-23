import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_common_elements(dut):
    """Test common_elements module with various test cases"""
    
    # Helper to format list as hex for display
    def format_list(lst):
        return [hex(x) for x in lst]
    
    # Test case 1: Original example
    dut.list1[0].value = 1
    dut.list1[1].value = 4
    dut.list1[2].value = 3
    dut.list1[3].value = 34
    dut.list1[4].value = 653
    dut.list1[5].value = 2
    dut.list1[6].value = 5
    dut.list1[7].value = 0
    
    dut.list2[0].value = 5
    dut.list2[1].value = 7
    dut.list2[2].value = 1
    dut.list2[3].value = 5
    dut.list2[4].value = 9
    dut.list2[5].value = 653
    dut.list2[6].value = 121
    dut.list2[7].value = 0
    
    await Timer(10, units='ns')
    
    result = [int(dut.result[i].value) for i in range(8)]
    count = int(dut.count.value)
    
    print(f"Test 1: list1=[1,4,3,34,653,2,5,0], list2=[5,7,1,5,9,653,121,0]")
    print(f"Result: {format_list(result)}, Count: {count}")
    assert count == 3, f"Expected count=3, got {count}"
    assert result[:3] == [1, 5, 653], f"Expected [1,5,653], got {result[:3]}"
    
    # Test case 2: Smaller set
    dut.list1[0].value = 5
    dut.list1[1].value = 3
    dut.list1[2].value = 2
    dut.list1[3].value = 8
    dut.list1[4].value = 0
    dut.list1[5].value = 0
    dut.list1[6].value = 0
    dut.list1[7].value = 0
    
    dut.list2[0].value = 3
    dut.list2[1].value = 2
    dut.list2[2].value = 0
    dut.list2[3].value = 0
    dut.list2[4].value = 0
    dut.list2[5].value = 0
    dut.list2[6].value = 0
    dut.list2[7].value = 0
    
    await Timer(10, units='ns')
    
    result = [int(dut.result[i].value) for i in range(8)]
    count = int(dut.count.value)
    
    print(f"Test 2: list1=[5,3,2,8,0,0,0,0], list2=[3,2,0,0,0,0,0,0]")
    print(f"Result: {format_list(result)}, Count: {count}")
    assert count == 2, f"Expected count=2, got {count}"
    assert result[:2] == [2, 3], f"Expected [2,3], got {result[:2]}"
    
    # Test case 3: All common
    dut.list1[0].value = 4
    dut.list1[1].value = 3
    dut.list1[2].value = 2
    dut.list1[3].value = 8
    dut.list1[4].value = 0
    dut.list1[5].value = 0
    dut.list1[6].value = 0
    dut.list1[7].value = 0
    
    dut.list2[0].value = 3
    dut.list2[1].value = 2
    dut.list2[2].value = 4
    dut.list2[3].value = 0
    dut.list2[4].value = 0
    dut.list2[5].value = 0
    dut.list2[6].value = 0
    dut.list2[7].value = 0
    
    await Timer(10, units='ns')
    
    result = [int(dut.result[i].value) for i in range(8)]
    count = int(dut.count.value)
    
    print(f"Test 3: list1=[4,3,2,8,0,0,0,0], list2=[3,2,4,0,0,0,0,0]")
    print(f"Result: {format_list(result)}, Count: {count}")
    assert count == 3, f"Expected count=3, got {count}"
    assert result[:3] == [2, 3, 4], f"Expected [2,3,4], got {result[:3]}"
    
    # Test case 4: Empty intersection
    dut.list1[0].value = 4
    dut.list1[1].value = 3
    dut.list1[2].value = 2
    dut.list1[3].value = 8
    dut.list1[4].value = 0
    dut.list1[5].value = 0
    dut.list1[6].value = 0
    dut.list1[7].value = 0
    
    dut.list2[0].value = 0
    dut.list2[1].value = 0
    dut.list2[2].value = 0
    dut.list2[3].value = 0
    dut.list2[4].value = 0
    dut.list2[5].value = 0
    dut.list2[6].value = 0
    dut.list2[7].value = 0
    
    await Timer(10, units='ns')
    
    result = [int(dut.result[i].value) for i in range(8)]
    count = int(dut.count.value)
    
    print(f"Test 4: list1=[4,3,2,8,0,0,0,0], list2=[0,0,0,0,0,0,0,0]")
    print(f"Result: {format_list(result)}, Count: {count}")
    assert count == 0, f"Expected count=0, got {count}"
    
    print("All 4/4 tests passed!")