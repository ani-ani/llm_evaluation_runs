import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_extract_even(dut):
    """Test extraction of even elements from nested structure"""
    
    # Test case 1: (4, 5, (7, 6, (2, 4)), 6, 8)
    # Simplified to: [4,5,6,8] and nested [7,6,2,4]
    # Expected: [4,6,8] and nested [6,2,4] -> flattened [4,6,8,6,2,4] (limited to 4 outputs)
    dut.level1_0.value = 4
    dut.level1_1.value = 5
    dut.level1_2.value = 6
    dut.level1_3.value = 8
    dut.level2_0.value = 7
    dut.level2_1.value = 6
    dut.level2_2.value = 2
    dut.level2_3.value = 4
    
    await Timer(10, units='ns')
    
    # Check results
    result = [int(dut.result_0.value), int(dut.result_1.value), int(dut.result_2.value), int(dut.result_3.value)]
    valid_count = int(dut.valid_count.value)
    
    print(f"Test 1 - Result: {result}, Valid count: {valid_count}")
    assert valid_count == 4, f"Expected 4 valid elements, got {valid_count}"
    assert result[0] == 4, f"Expected result_0=4, got {result[0]}"
    assert result[1] == 6, f"Expected result_1=6, got {result[1]}"
    assert result[2] == 8, f"Expected result_2=8, got {result[2]}"
    assert result[3] == 6, f"Expected result_3=6, got {result[3]}"
    
    # Test case 2: (5, 6, (8, 7, (4, 8)), 7, 9)
    # Simplified: [5,6,7,9] and nested [8,7,4,8]
    # Expected: [6] and nested [8,4,8] -> flattened [6,8,4,8]
    dut.level1_0.value = 5
    dut.level1_1.value = 6
    dut.level1_2.value = 7
    dut.level1_3.value = 9
    dut.level2_0.value = 8
    dut.level2_1.value = 7
    dut.level2_2.value = 4
    dut.level2_3.value = 8
    
    await Timer(10, units='ns')
    
    result = [int(dut.result_0.value), int(dut.result_1.value), int(dut.result_2.value), int(dut.result_3.value)]
    valid_count = int(dut.valid_count.value)
    
    print(f"Test 2 - Result: {result}, Valid count: {valid_count}")
    assert valid_count == 4, f"Expected 4 valid elements, got {valid_count}"
    assert result[0] == 6, f"Expected result_0=6, got {result[0]}"
    assert result[1] == 8, f"Expected result_1=8, got {result[1]}"
    assert result[2] == 4, f"Expected result_2=4, got {result[2]}"
    assert result[3] == 8, f"Expected result_3=8, got {result[3]}"
    
    # Test case 3: (5, 6, (9, 8, (4, 6)), 8, 10)
    # Simplified: [5,6,8,10] and nested [9,8,4,6]
    # Expected: [6,8,10] and nested [8,4,6] -> flattened [6,8,10,8]
    dut.level1_0.value = 5
    dut.level1_1.value = 6
    dut.level1_2.value = 8
    dut.level1_3.value = 10
    dut.level2_0.value = 9
    dut.level2_1.value = 8
    dut.level2_2.value = 4
    dut.level2_3.value = 6
    
    await Timer(10, units='ns')
    
    result = [int(dut.result_0.value), int(dut.result_1.value), int(dut.result_2.value), int(dut.result_3.value)]
    valid_count = int(dut.valid_count.value)
    
    print(f"Test 3 - Result: {result}, Valid count: {valid_count}")
    assert valid_count == 4, f"Expected 4 valid elements, got {valid_count}"
    assert result[0] == 6, f"Expected result_0=6, got {result[0]}"
    assert result[1] == 8, f"Expected result_1=8, got {result[1]}"
    assert result[2] == 10, f"Expected result_2=10, got {result[2]}"
    assert result[3] == 8, f"Expected result_3=8, got {result[3]}"
    
    # Edge case: All odd numbers
    dut.level1_0.value = 1
    dut.level1_1.value = 3
    dut.level1_2.value = 5
    dut.level1_3.value = 7
    dut.level2_0.value = 9
    dut.level2_1.value = 11
    dut.level2_2.value = 13
    dut.level2_3.value = 15
    
    await Timer(10, units='ns')
    
    result = [int(dut.result_0.value), int(dut.result_1.value), int(dut.result_2.value), int(dut.result_3.value)]
    valid_count = int(dut.valid_count.value)
    
    print(f"Edge case - Result: {result}, Valid count: {valid_count}")
    assert valid_count == 0, f"Expected 0 valid elements, got {valid_count}"
    
    # Edge case: All even numbers (including 0)
    dut.level1_0.value = 0
    dut.level1_1.value = 2
    dut.level1_2.value = 4
    dut.level1_3.value = 6
    dut.level2_0.value = 8
    dut.level2_1.value = 10
    dut.level2_2.value = 12
    dut.level2_3.value = 14
    
    await Timer(10, units='ns')
    
    result = [int(dut.result_0.value), int(dut.result_1.value), int(dut.result_2.value), int(dut.result_3.value)]
    valid_count = int(dut.valid_count.value)
    
    print(f"All even - Result: {result}, Valid count: {valid_count}")
    assert valid_count == 4, f"Expected 4 valid elements, got {valid_count}"
    assert result[0] == 0, f"Expected result_0=0, got {result[0]}"
    assert result[1] == 2, f"Expected result_1=2, got {result[1]}"
    assert result[2] == 4, f"Expected result_2=4, got {result[2]}"
    assert result[3] == 6, f"Expected result_3=6, got {result[3]}"
    
    print("
All tests completed successfully!")