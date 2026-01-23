import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_sum_even_even_pos(dut):
    """Test sum of even numbers at even positions"""
    
    # Test Case 1: [5, 6, 12, 1, 18, 8, 0, 0] -> even indices 0,2,4,6: 5,12,18,0 -> even values: 12,18,0 -> sum = 30
    dut.arr[0] = 5
    dut.arr[1] = 6
    dut.arr[2] = 12
    dut.arr[3] = 1
    dut.arr[4] = 18
    dut.arr[5] = 8
    dut.arr[6] = 0
    dut.arr[7] = 0
    await Timer(1, units='ns')
    assert dut.sum.value == 30, f"Test 1 failed: expected 30, got {dut.sum.value}"
    print("Test 1 passed: [5, 6, 12, 1, 18, 8, 0, 0] -> sum = 30")
    
    # Test Case 2: [3, 20, 17, 9, 2, 10, 18, 13] -> even indices 0,2,4,6: 3,17,2,18 -> even values: 2,18 -> sum = 20
    dut.arr[0] = 3
    dut.arr[1] = 20
    dut.arr[2] = 17
    dut.arr[3] = 9
    dut.arr[4] = 2
    dut.arr[5] = 10
    dut.arr[6] = 18
    dut.arr[7] = 13
    await Timer(1, units='ns')
    assert dut.sum.value == 20, f"Test 2 failed: expected 20, got {dut.sum.value}"
    print("Test 2 passed: [3, 20, 17, 9, 2, 10, 18, 13] -> sum = 20")
    
    # Test Case 3: [5, 6, 12, 1, 0, 0, 0, 0] -> even indices 0,2,4,6: 5,12,0,0 -> even values: 12,0 -> sum = 12
    dut.arr[0] = 5
    dut.arr[1] = 6
    dut.arr[2] = 12
    dut.arr[3] = 1
    dut.arr[4] = 0
    dut.arr[5] = 0
    dut.arr[6] = 0
    dut.arr[7] = 0
    await Timer(1, units='ns')
    assert dut.sum.value == 12, f"Test 3 failed: expected 12, got {dut.sum.value}"
    print("Test 3 passed: [5, 6, 12, 1, 0, 0, 0, 0] -> sum = 12")
    
    # Test Case 4: All even numbers at even positions
    dut.arr[0] = 2
    dut.arr[1] = 1
    dut.arr[2] = 4
    dut.arr[3] = 3
    dut.arr[4] = 6
    dut.arr[5] = 5
    dut.arr[6] = 8
    dut.arr[7] = 7
    await Timer(1, units='ns')
    assert dut.sum.value == 20, f"Test 4 failed: expected 20, got {dut.sum.value}"
    print("Test 4 passed: [2, 1, 4, 3, 6, 5, 8, 7] -> sum = 20")
    
    # Test Case 5: All odd numbers at even positions (should be 0)
    dut.arr[0] = 1
    dut.arr[1] = 2
    dut.arr[2] = 3
    dut.arr[3] = 4
    dut.arr[4] = 5
    dut.arr[5] = 6
    dut.arr[6] = 7
    dut.arr[7] = 8
    await Timer(1, units='ns')
    assert dut.sum.value == 0, f"Test 5 failed: expected 0, got {dut.sum.value}"
    print("Test 5 passed: [1, 2, 3, 4, 5, 6, 7, 8] -> sum = 0")
    
    # Test Case 6: Maximum values (255 at even positions, 255 is odd, so sum = 0)
    dut.arr[0] = 255
    dut.arr[1] = 0
    dut.arr[2] = 255
    dut.arr[3] = 0
    dut.arr[4] = 255
    dut.arr[5] = 0
    dut.arr[6] = 255
    dut.arr[7] = 0
    await Timer(1, units='ns')
    assert dut.sum.value == 0, f"Test 6 failed: expected 0, got {dut.sum.value}"
    print("Test 6 passed: All 255 (odd) at even positions -> sum = 0")
    
    # Test Case 7: Maximum even values at even positions (252 = 0xFC)
    dut.arr[0] = 252
    dut.arr[1] = 0
    dut.arr[2] = 252
    dut.arr[3] = 0
    dut.arr[4] = 252
    dut.arr[5] = 0
    dut.arr[6] = 252
    dut.arr[7] = 0
    await Timer(1, units='ns')
    expected_sum = 252 * 4  # 1008
    assert dut.sum.value == expected_sum, f"Test 7 failed: expected {expected_sum}, got {dut.sum.value}"
    print(f"Test 7 passed: [252, 0, 252, 0, 252, 0, 252, 0] -> sum = {expected_sum}")
    
    print("
All 7 tests passed successfully!")
