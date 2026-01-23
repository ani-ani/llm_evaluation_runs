import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_add_even_at_odd_indices(dut):
    """Test the add_even_at_odd_indices module with various test cases"""
    
    # Test Case 1: [4, 88] -> only index 1 checked (88 is even)
    # In our 8-element array, this is [4, 88, 0, 0, 0, 0, 0, 0]
    dut.arr[0] = 4
    dut.arr[1] = 88
    dut.arr[2] = 0
    dut.arr[3] = 0
    dut.arr[4] = 0
    dut.arr[5] = 0
    dut.arr[6] = 0
    dut.arr[7] = 0
    await Timer(10, units='ns')
    assert dut.result.value == 88, f"Test 1 failed: expected 88, got {dut.result.value}"
    print("Test 1 passed: [4, 88] -> 88")
    
    # Test Case 2: [4, 5, 6, 7, 2, 122] -> indices 1, 3, 5 checked
    # arr[1]=5 (odd), arr[3]=7 (odd), arr[5]=122 (even) -> sum=122
    dut.arr[0] = 4
    dut.arr[1] = 5
    dut.arr[2] = 6
    dut.arr[3] = 7
    dut.arr[4] = 2
    dut.arr[5] = 122
    dut.arr[6] = 0
    dut.arr[7] = 0
    await Timer(10, units='ns')
    assert dut.result.value == 122, f"Test 2 failed: expected 122, got {dut.result.value}"
    print("Test 2 passed: [4, 5, 6, 7, 2, 122] -> 122")
    
    # Test Case 3: [4, 0, 6, 7] -> indices 1, 3 checked
    # arr[1]=0 (even), arr[3]=7 (odd) -> sum=0
    dut.arr[0] = 4
    dut.arr[1] = 0
    dut.arr[2] = 6
    dut.arr[3] = 7
    dut.arr[4] = 0
    dut.arr[5] = 0
    dut.arr[6] = 0
    dut.arr[7] = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 3 failed: expected 0, got {dut.result.value}"
    print("Test 3 passed: [4, 0, 6, 7] -> 0")
    
    # Test Case 4: [4, 4, 6, 8] -> indices 1, 3 checked
    # arr[1]=4 (even), arr[3]=8 (even) -> sum=12
    dut.arr[0] = 4
    dut.arr[1] = 4
    dut.arr[2] = 6
    dut.arr[3] = 8
    dut.arr[4] = 0
    dut.arr[5] = 0
    dut.arr[6] = 0
    dut.arr[7] = 0
    await Timer(10, units='ns')
    assert dut.result.value == 12, f"Test 4 failed: expected 12, got {dut.result.value}"
    print("Test 4 passed: [4, 4, 6, 8] -> 12")
    
    # Test Case 5: All odd indices with even numbers at all odd positions
    # [0, 2, 0, 4, 0, 6, 0, 8] -> sum = 2+4+6+8 = 20
    dut.arr[0] = 0
    dut.arr[1] = 2
    dut.arr[2] = 0
    dut.arr[3] = 4
    dut.arr[4] = 0
    dut.arr[5] = 6
    dut.arr[6] = 0
    dut.arr[7] = 8
    await Timer(10, units='ns')
    assert dut.result.value == 20, f"Test 5 failed: expected 20, got {dut.result.value}"
    print("Test 5 passed: [0, 2, 0, 4, 0, 6, 0, 8] -> 20")
    
    # Test Case 6: All even numbers but at even indices (should return 0)
    # [2, 1, 4, 3, 6, 5, 8, 7] -> only indices 1,3,5,7 checked (1,3,5,7 are odd)
    # arr[1]=1 (odd), arr[3]=3 (odd), arr[5]=5 (odd), arr[7]=7 (odd) -> sum=0
    dut.arr[0] = 2
    dut.arr[1] = 1
    dut.arr[2] = 4
    dut.arr[3] = 3
    dut.arr[4] = 6
    dut.arr[5] = 5
    dut.arr[6] = 8
    dut.arr[7] = 7
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 6 failed: expected 0, got {dut.result.value}"
    print("Test 6 passed: [2, 1, 4, 3, 6, 5, 8, 7] -> 0")
    
    print("
All tests completed successfully!")
    print("6/6 tests passed")
