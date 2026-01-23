import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_list_append(dut):
    """Test list append functionality"""
    
    # Test 1: list=[5,6,7], tuple=(9,10) -> result=(9,10,5,6,7)
    dut.list_data[0].value = 5
    dut.list_data[1].value = 6
    dut.list_data[2].value = 7
    dut.list_len.value = 3
    
    dut.tuple_data[0].value = 9
    dut.tuple_data[1].value = 10
    dut.tuple_len.value = 2
    
    await Timer(1, units='ns')
    
    # Check result
    assert dut.result_len.value == 5, f"Expected len=5, got {dut.result_len.value}"
    assert dut.result[0].value == 9, f"Expected result[0]=9, got {dut.result[0].value}"
    assert dut.result[1].value == 10, f"Expected result[1]=10, got {dut.result[1].value}"
    assert dut.result[2].value == 5, f"Expected result[2]=5, got {dut.result[2].value}"
    assert dut.result[3].value == 6, f"Expected result[3]=6, got {dut.result[3].value}"
    assert dut.result[4].value == 7, f"Expected result[4]=7, got {dut.result[4].value}"
    print("Test 1 passed: [5,6,7] + (9,10) = (9,10,5,6,7)")
    
    # Test 2: list=[6,7,8], tuple=(10,11) -> result=(10,11,6,7,8)
    dut.list_data[0].value = 6
    dut.list_data[1].value = 7
    dut.list_data[2].value = 8
    dut.list_len.value = 3
    
    dut.tuple_data[0].value = 10
    dut.tuple_data[1].value = 11
    dut.tuple_len.value = 2
    
    await Timer(1, units='ns')
    
    assert dut.result_len.value == 5, f"Expected len=5, got {dut.result_len.value}"
    assert dut.result[0].value == 10, f"Expected result[0]=10, got {dut.result[0].value}"
    assert dut.result[1].value == 11, f"Expected result[1]=11, got {dut.result[1].value}"
    assert dut.result[2].value == 6, f"Expected result[2]=6, got {dut.result[2].value}"
    assert dut.result[3].value == 7, f"Expected result[3]=7, got {dut.result[3].value}"
    assert dut.result[4].value == 8, f"Expected result[4]=8, got {dut.result[4].value}"
    print("Test 2 passed: [6,7,8] + (10,11) = (10,11,6,7,8)")
    
    # Test 3: list=[7,8,9], tuple=(11,12) -> result=(11,12,7,8,9)
    dut.list_data[0].value = 7
    dut.list_data[1].value = 8
    dut.list_data[2].value = 9
    dut.list_len.value = 3
    
    dut.tuple_data[0].value = 11
    dut.tuple_data[1].value = 12
    dut.tuple_len.value = 2
    
    await Timer(1, units='ns')
    
    assert dut.result_len.value == 5, f"Expected len=5, got {dut.result_len.value}"
    assert dut.result[0].value == 11, f"Expected result[0]=11, got {dut.result[0].value}"
    assert dut.result[1].value == 12, f"Expected result[1]=12, got {dut.result[1].value}"
    assert dut.result[2].value == 7, f"Expected result[2]=7, got {dut.result[2].value}"
    assert dut.result[3].value == 8, f"Expected result[3]=8, got {dut.result[3].value}"
    assert dut.result[4].value == 9, f"Expected result[4]=9, got {dut.result[4].value}"
    print("Test 3 passed: [7,8,9] + (11,12) = (11,12,7,8,9)")
    
    # Edge case: empty list
    dut.list_len.value = 0
    dut.tuple_data[0].value = 1
    dut.tuple_data[1].value = 2
    dut.tuple_len.value = 2
    await Timer(1, units='ns')
    assert dut.result_len.value == 2, f"Empty list: Expected len=2, got {dut.result_len.value}"
    assert dut.result[0].value == 1, f"Empty list: Expected result[0]=1"
    assert dut.result[1].value == 2, f"Empty list: Expected result[1]=2"
    print("Edge case 1 passed: empty list")
    
    # Edge case: empty tuple
    dut.list_data[0].value = 5
    dut.list_len.value = 1
    dut.tuple_len.value = 0
    await Timer(1, units='ns')
    assert dut.result_len.value == 1, f"Empty tuple: Expected len=1, got {dut.result_len.value}"
    assert dut.result[0].value == 5, f"Empty tuple: Expected result[0]=5"
    print("Edge case 2 passed: empty tuple")
    
    # Edge case: overflow (tuple_len + list_len > 8)
    # 4 + 5 = 9 > 8, so result should be truncated
    for i in range(5):
        dut.list_data[i].value = 20 + i
    dut.list_len.value = 5
    for i in range(4):
        dut.tuple_data[i].value = 10 + i
    dut.tuple_len.value = 4
    await Timer(1, units='ns')
    # Should fit: 4 tuple + 4 list = 8 (one element truncated from list)
    assert dut.result_len.value == 8, f"Overflow: Expected len=8, got {dut.result_len.value}"
    print("Edge case 3 passed: overflow handling")
    
    passed = 6
    total = 6
    print(f"
Summary: {passed}/{total} tests passed")