import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_and_tuples(dut):
    """Test elementwise AND operation on tuples"""
    
    # Test Case 1: (10, 4, 6, 9) & (5, 2, 3, 3) = (0, 0, 2, 1)
    dut.tuple1_0.value = 10
    dut.tuple1_1.value = 4
    dut.tuple1_2.value = 6
    dut.tuple1_3.value = 9
    dut.tuple2_0.value = 5
    dut.tuple2_1.value = 2
    dut.tuple2_2.value = 3
    dut.tuple2_3.value = 3
    
    await Timer(1, units='ns')
    
    assert int(dut.result_0.value) == 0, f"Test 1 failed: result_0 expected 0, got {int(dut.result_0.value)}"
    assert int(dut.result_1.value) == 0, f"Test 1 failed: result_1 expected 0, got {int(dut.result_1.value)}"
    assert int(dut.result_2.value) == 2, f"Test 1 failed: result_2 expected 2, got {int(dut.result_2.value)}"
    assert int(dut.result_3.value) == 1, f"Test 1 failed: result_3 expected 1, got {int(dut.result_3.value)}"
    print("Test 1 passed: (10, 4, 6, 9) & (5, 2, 3, 3) = (0, 0, 2, 1)")
    
    # Test Case 2: (1, 2, 3, 4) & (5, 6, 7, 8) = (1, 2, 3, 0)
    dut.tuple1_0.value = 1
    dut.tuple1_1.value = 2
    dut.tuple1_2.value = 3
    dut.tuple1_3.value = 4
    dut.tuple2_0.value = 5
    dut.tuple2_1.value = 6
    dut.tuple2_2.value = 7
    dut.tuple2_3.value = 8
    
    await Timer(1, units='ns')
    
    assert int(dut.result_0.value) == 1, f"Test 2 failed: result_0 expected 1, got {int(dut.result_0.value)}"
    assert int(dut.result_1.value) == 2, f"Test 2 failed: result_1 expected 2, got {int(dut.result_1.value)}"
    assert int(dut.result_2.value) == 3, f"Test 2 failed: result_2 expected 3, got {int(dut.result_2.value)}"
    assert int(dut.result_3.value) == 0, f"Test 2 failed: result_3 expected 0, got {int(dut.result_3.value)}"
    print("Test 2 passed: (1, 2, 3, 4) & (5, 6, 7, 8) = (1, 2, 3, 0)")
    
    # Test Case 3: (8, 9, 11, 12) & (7, 13, 14, 17) = (0, 9, 10, 0)
    dut.tuple1_0.value = 8
    dut.tuple1_1.value = 9
    dut.tuple1_2.value = 11
    dut.tuple1_3.value = 12
    dut.tuple2_0.value = 7
    dut.tuple2_1.value = 13
    dut.tuple2_2.value = 14
    dut.tuple2_3.value = 17
    
    await Timer(1, units='ns')
    
    assert int(dut.result_0.value) == 0, f"Test 3 failed: result_0 expected 0, got {int(dut.result_0.value)}"
    assert int(dut.result_1.value) == 9, f"Test 3 failed: result_1 expected 9, got {int(dut.result_1.value)}"
    assert int(dut.result_2.value) == 10, f"Test 3 failed: result_2 expected 10, got {int(dut.result_2.value)}"
    assert int(dut.result_3.value) == 0, f"Test 3 failed: result_3 expected 0, got {int(dut.result_3.value)}"
    print("Test 3 passed: (8, 9, 11, 12) & (7, 13, 14, 17) = (0, 9, 10, 0)")
    
    # Test Case 4: Edge case with zeros
    dut.tuple1_0.value = 0
    dut.tuple1_1.value = 255
    dut.tuple1_2.value = 0xAA
    dut.tuple1_3.value = 0x55
    dut.tuple2_0.value = 0
    dut.tuple2_1.value = 255
    dut.tuple2_2.value = 0x55
    dut.tuple2_3.value = 0xAA
    
    await Timer(1, units='ns')
    
    assert int(dut.result_0.value) == 0, f"Test 4 failed: result_0 expected 0, got {int(dut.result_0.value)}"
    assert int(dut.result_1.value) == 255, f"Test 4 failed: result_1 expected 255, got {int(dut.result_1.value)}"
    assert int(dut.result_2.value) == 0x00, f"Test 4 failed: result_2 expected 0, got {int(dut.result_2.value)}"
    assert int(dut.result_3.value) == 0x00, f"Test 4 failed: result_3 expected 0, got {int(dut.result_3.value)}"
    print("Test 4 passed: Edge cases with zeros and full byte values")
    
    # Test Case 5: All same values
    dut.tuple1_0.value = 15
    dut.tuple1_1.value = 15
    dut.tuple1_2.value = 15
    dut.tuple1_3.value = 15
    dut.tuple2_0.value = 15
    dut.tuple2_1.value = 15
    dut.tuple2_2.value = 15
    dut.tuple2_3.value = 15
    
    await Timer(1, units='ns')
    
    assert int(dut.result_0.value) == 15, f"Test 5 failed: result_0 expected 15, got {int(dut.result_0.value)}"
    assert int(dut.result_1.value) == 15, f"Test 5 failed: result_1 expected 15, got {int(dut.result_1.value)}"
    assert int(dut.result_2.value) == 15, f"Test 5 failed: result_2 expected 15, got {int(dut.result_2.value)}"
    assert int(dut.result_3.value) == 15, f"Test 5 failed: result_3 expected 15, got {int(dut.result_3.value)}"
    print("Test 5 passed: (15, 15, 15, 15) & (15, 15, 15, 15) = (15, 15, 15, 15)")
    
    print("
All 5/5 tests passed successfully!")