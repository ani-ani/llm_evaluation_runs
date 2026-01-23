import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_max_diff(dut):
    """Test the max_diff module with various test cases"""
    
    # Helper function to set array values
    def set_array(arr):
        for i in range(8):
            if i < len(arr):
                setattr(dut, f'arr_{i}', arr[i])
            else:
                setattr(dut, f'arr_{i}', 0)
        dut.valid_count.value = len(arr)
    
    # Test 1: [2,1,5,3] -> expected 4
    set_array([2, 1, 5, 3])
    await Timer(10, units='ns')
    result = int(dut.max_diff_result.value)
    assert result == 4, f"Test 1 failed: expected 4, got {result}"
    print(f"Test 1 passed: [2,1,5,3] -> {result}")
    
    # Test 2: [9,3,2,5,1] -> expected 8
    set_array([9, 3, 2, 5, 1])
    await Timer(10, units='ns')
    result = int(dut.max_diff_result.value)
    assert result == 8, f"Test 2 failed: expected 8, got {result}"
    print(f"Test 2 passed: [9,3,2,5,1] -> {result}")
    
    # Test 3: [3,2,1] -> expected 2
    set_array([3, 2, 1])
    await Timer(10, units='ns')
    result = int(dut.max_diff_result.value)
    assert result == 2, f"Test 3 failed: expected 2, got {result}"
    print(f"Test 3 passed: [3,2,1] -> {result}")
    
    # Test 4: [100,50,200,150] -> expected 150
    set_array([100, 50, 200, 150])
    await Timer(10, units='ns')
    result = int(dut.max_diff_result.value)
    assert result == 150, f"Test 4 failed: expected 150, got {result}"
    print(f"Test 4 passed: [100,50,200,150] -> {result}")
    
    # Test 5: Single element [5] -> expected 0
    set_array([5])
    await Timer(10, units='ns')
    result = int(dut.max_diff_result.value)
    assert result == 0, f"Test 5 failed: expected 0, got {result}"
    print(f"Test 5 passed: [5] -> {result}")
    
    print("
All tests passed!")