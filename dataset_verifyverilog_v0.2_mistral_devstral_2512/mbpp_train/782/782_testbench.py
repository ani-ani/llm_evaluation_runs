import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

def odd_length_sum_py(arr):
    """Python reference implementation"""
    total = 0
    l = len(arr)
    for i in range(l):
        weight = ((i + 1) * (l - i) + 1) // 2
        total += weight * arr[i]
    return total

@cocotb.test()
async def test_odd_length_sum(dut):
    """Test odd_length_sum module with various array lengths and values"""
    
    # Test case 1: [1,2,4] -> expected 14
    dut.arr_0.value = 1
    dut.arr_1.value = 2
    dut.arr_2.value = 4
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    dut.length.value = 3
    await Timer(1, units='ns')
    result = int(dut.result.value)
    expected = odd_length_sum_py([1,2,4])
    assert result == expected, f"Test 1 failed: got {result}, expected {expected}"
    print(f"Test 1 passed: [1,2,4] = {result}")
    
    # Test case 2: [1,2,1,2] -> expected 15
    dut.arr_0.value = 1
    dut.arr_1.value = 2
    dut.arr_2.value = 1
    dut.arr_3.value = 2
    dut.length.value = 4
    await Timer(1, units='ns')
    result = int(dut.result.value)
    expected = odd_length_sum_py([1,2,1,2])
    assert result == expected, f"Test 2 failed: got {result}, expected {expected}"
    print(f"Test 2 passed: [1,2,1,2] = {result}")
    
    # Test case 3: [1,7] -> expected 8
    dut.arr_0.value = 1
    dut.arr_1.value = 7
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    dut.length.value = 2
    await Timer(1, units='ns')
    result = int(dut.result.value)
    expected = odd_length_sum_py([1,7])
    assert result == expected, f"Test 3 failed: got {result}, expected {expected}"
    print(f"Test 3 passed: [1,7] = {result}")
    
    # Test case 4: Single element [5] -> expected 5
    dut.arr_0.value = 5
    dut.arr_1.value = 0
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    dut.length.value = 1
    await Timer(1, units='ns')
    result = int(dut.result.value)
    expected = odd_length_sum_py([5])
    assert result == expected, f"Test 4 failed: got {result}, expected {expected}"
    print(f"Test 4 passed: [5] = {result}")
    
    # Test case 5: Full array [1,2,3,4,5,6,7,8] -> verify calculation
    dut.arr_0.value = 1
    dut.arr_1.value = 2
    dut.arr_2.value = 3
    dut.arr_3.value = 4
    dut.arr_4.value = 5
    dut.arr_5.value = 6
    dut.arr_6.value = 7
    dut.arr_7.value = 8
    dut.length.value = 8
    await Timer(1, units='ns')
    result = int(dut.result.value)
    expected = odd_length_sum_py([1,2,3,4,5,6,7,8])
    assert result == expected, f"Test 5 failed: got {result}, expected {expected}"
    print(f"Test 5 passed: [1,2,3,4,5,6,7,8] = {result}")
    
    # Test case 6: Boundary test with large values
    dut.arr_0.value = 200
    dut.arr_1.value = 100
    dut.arr_2.value = 50
    dut.arr_3.value = 25
    dut.length.value = 4
    await Timer(1, units='ns')
    result = int(dut.result.value)
    expected = odd_length_sum_py([200,100,50,25])
    assert result == expected, f"Test 6 failed: got {result}, expected {expected}"
    print(f"Test 6 passed: [200,100,50,25] = {result}")
    
    passed = 6
    total = 6
    print(f"
{passed}/{total} tests passed")
