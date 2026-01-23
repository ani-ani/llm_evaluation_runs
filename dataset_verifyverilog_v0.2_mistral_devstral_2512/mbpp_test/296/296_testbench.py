import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_inversion_counter(dut):
    """Test inversion counter with various test cases"""
    
    # Test case 1: [1,20,6,4,5] -> 5 inversions
    dut.arr_0.value = 1
    dut.arr_1.value = 20
    dut.arr_2.value = 6
    dut.arr_3.value = 4
    dut.arr_4.value = 5
    dut.arr_5.value = 0  # Unused
    dut.arr_6.value = 0  # Unused
    dut.arr_7.value = 0  # Unused
    await Timer(10, units='ns')
    result = int(dut.inv_count.value)
    print(f"Test 1: [1,20,6,4,5] -> {result} (expected 5)")
    assert result == 5, f"Expected 5, got {result}"
    
    # Test case 2: [1,2,1] -> 1 inversion
    dut.arr_0.value = 1
    dut.arr_1.value = 2
    dut.arr_2.value = 1
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.inv_count.value)
    print(f"Test 2: [1,2,1] -> {result} (expected 1)")
    assert result == 1, f"Expected 1, got {result}"
    
    # Test case 3: [1,2,5,6,1] -> 3 inversions
    dut.arr_0.value = 1
    dut.arr_1.value = 2
    dut.arr_2.value = 5
    dut.arr_3.value = 6
    dut.arr_4.value = 1
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.inv_count.value)
    print(f"Test 3: [1,2,5,6,1] -> {result} (expected 3)")
    assert result == 3, f"Expected 3, got {result}"
    
    # Test case 4: [5,4,3,2,1] -> 10 inversions
    dut.arr_0.value = 5
    dut.arr_1.value = 4
    dut.arr_2.value = 3
    dut.arr_3.value = 2
    dut.arr_4.value = 1
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.inv_count.value)
    print(f"Test 4: [5,4,3,2,1] -> {result} (expected 10)")
    assert result == 10, f"Expected 10, got {result}"
    
    # Test case 5: [1,2,3,4,5] -> 0 inversions
    dut.arr_0.value = 1
    dut.arr_1.value = 2
    dut.arr_2.value = 3
    dut.arr_3.value = 4
    dut.arr_4.value = 5
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.inv_count.value)
    print(f"Test 5: [1,2,3,4,5] -> {result} (expected 0)")
    assert result == 0, f"Expected 0, got {result}"
    
    # Test case 6: All same values [3,3,3,3] -> 0 inversions
    dut.arr_0.value = 3
    dut.arr_1.value = 3
    dut.arr_2.value = 3
    dut.arr_3.value = 3
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.inv_count.value)
    print(f"Test 6: [3,3,3,3] -> {result} (expected 0)")
    assert result == 0, f"Expected 0, got {result}"
    
    print("
All tests passed!")