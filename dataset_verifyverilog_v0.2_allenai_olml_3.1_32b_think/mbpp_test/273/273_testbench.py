import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_subtract(dut):
    """Test element-wise tuple subtraction"""
    
    # Test case 1: (10, 4, 5) - (2, 5, 18) = (8, -1, -13)
    dut.tuple1_0.value = 10
    dut.tuple1_1.value = 4
    dut.tuple1_2.value = 5
    dut.tuple2_0.value = 2
    dut.tuple2_1.value = 5
    dut.tuple2_2.value = 18
    await Timer(1, units='ns')
    assert int(dut.result_0.value) == 8, f"Test 1 result_0: expected 8, got {int(dut.result_0.value)}"
    assert int(dut.result_1.value) == 255, f"Test 1 result_1: expected -1 (255 in unsigned), got {int(dut.result_1.value)}"
    assert int(dut.result_2.value) == 243, f"Test 1 result_2: expected -13 (243 in unsigned), got {int(dut.result_2.value)}"
    print("Test 1 passed: (10,4,5) - (2,5,18) = (8,-1,-13)")
    
    # Test case 2: (11, 2, 3) - (24, 45, 16) = (-13, -43, -13)
    dut.tuple1_0.value = 11
    dut.tuple1_1.value = 2
    dut.tuple1_2.value = 3
    dut.tuple2_0.value = 24
    dut.tuple2_1.value = 45
    dut.tuple2_2.value = 16
    await Timer(1, units='ns')
    assert int(dut.result_0.value) == 243, f"Test 2 result_0: expected -13 (243 in unsigned), got {int(dut.result_0.value)}"
    assert int(dut.result_1.value) == 213, f"Test 2 result_1: expected -43 (213 in unsigned), got {int(dut.result_1.value)}"
    assert int(dut.result_2.value) == 243, f"Test 2 result_2: expected -13 (243 in unsigned), got {int(dut.result_2.value)}"
    print("Test 2 passed: (11,2,3) - (24,45,16) = (-13,-43,-13)")
    
    # Test case 3: (7, 18, 9) - (10, 11, 12) = (-3, 7, -3)
    dut.tuple1_0.value = 7
    dut.tuple1_1.value = 18
    dut.tuple1_2.value = 9
    dut.tuple2_0.value = 10
    dut.tuple2_1.value = 11
    dut.tuple2_2.value = 12
    await Timer(1, units='ns')
    assert int(dut.result_0.value) == 253, f"Test 3 result_0: expected -3 (253 in unsigned), got {int(dut.result_0.value)}"
    assert int(dut.result_1.value) == 7, f"Test 3 result_1: expected 7, got {int(dut.result_1.value)}"
    assert int(dut.result_2.value) == 253, f"Test 3 result_2: expected -3 (253 in unsigned), got {int(dut.result_2.value)}"
    print("Test 3 passed: (7,18,9) - (10,11,12) = (-3,7,-3)")
    
    # Edge case: Zero subtraction
    dut.tuple1_0.value = 0
    dut.tuple1_1.value = 0
    dut.tuple1_2.value = 0
    dut.tuple2_0.value = 0
    dut.tuple2_1.value = 0
    dut.tuple2_2.value = 0
    await Timer(1, units='ns')
    assert int(dut.result_0.value) == 0
    assert int(dut.result_1.value) == 0
    assert int(dut.result_2.value) == 0
    print("Edge case passed: (0,0,0) - (0,0,0) = (0,0,0)")
    
    print("
All 4 tests passed!")