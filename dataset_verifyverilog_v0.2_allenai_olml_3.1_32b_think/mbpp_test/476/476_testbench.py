import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_big_sum(dut):
    """Test the big_sum module with various test cases"""
    
    # Test case 1: [1, 2, 3] -> max=3, min=1, sum=4
    dut.array_size.value = 3
    dut.nums[0].value = 1
    dut.nums[1].value = 2
    dut.nums[2].value = 3
    # Initialize remaining elements
    for i in range(3, 8):
        dut.nums[i].value = 0
    
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 1: nums=[1,2,3] -> result={result}, expected=4")
    assert result == 4, f"Test 1 failed: got {result}, expected 4"
    
    # Test case 2: [-1, 2, 3, 4] -> max=4, min=-1, sum=3
    dut.array_size.value = 4
    dut.nums[0].value = -1 & 0xFF  # Two's complement for -1
    dut.nums[1].value = 2
    dut.nums[2].value = 3
    dut.nums[3].value = 4
    for i in range(4, 8):
        dut.nums[i].value = 0
    
    await Timer(10, units='ns')
    result = int(dut.result.value)
    # Convert from signed 8-bit if negative
    if result > 127:
        result = result - 256
    print(f"Test 2: nums=[-1,2,3,4] -> result={result}, expected=3")
    assert result == 3, f"Test 2 failed: got {result}, expected 3"
    
    # Test case 3: [2, 3, 6] -> max=6, min=2, sum=8
    dut.array_size.value = 3
    dut.nums[0].value = 2
    dut.nums[1].value = 3
    dut.nums[2].value = 6
    for i in range(3, 8):
        dut.nums[i].value = 0
    
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 3: nums=[2,3,6] -> result={result}, expected=8")
    assert result == 8, f"Test 3 failed: got {result}, expected 8"
    
    # Test case 4: Edge case - single element [5]
    dut.array_size.value = 1
    dut.nums[0].value = 5
    for i in range(1, 8):
        dut.nums[i].value = 0
    
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 4: nums=[5] -> result={result}, expected=10")
    assert result == 10, f"Test 4 failed: got {result}, expected 10"
    
    # Test case 5: All negative numbers [-5, -2, -10]
    dut.array_size.value = 3
    dut.nums[0].value = -5 & 0xFF
    dut.nums[1].value = -2 & 0xFF
    dut.nums[2].value = -10 & 0xFF
    for i in range(3, 8):
        dut.nums[i].value = 0
    
    await Timer(10, units='ns')
    result = int(dut.result.value)
    if result > 127:
        result = result - 256
    print(f"Test 5: nums=[-5,-2,-10] -> result={result}, expected=-12")
    assert result == -12, f"Test 5 failed: got {result}, expected -12"
    
    # Test case 6: Mixed large numbers [100, 127, -50]
    dut.array_size.value = 3
    dut.nums[0].value = 100
    dut.nums[1].value = 127
    dut.nums[2].value = -50 & 0xFF
    for i in range(3, 8):
        dut.nums[i].value = 0
    
    await Timer(10, units='ns')
    result = int(dut.result.value)
    if result > 127:
        result = result - 256
    print(f"Test 6: nums=[100,127,-50] -> result={result}, expected=77")
    assert result == 77, f"Test 6 failed: got {result}, expected 77"
    
    print(f"
=== All tests passed! ===")