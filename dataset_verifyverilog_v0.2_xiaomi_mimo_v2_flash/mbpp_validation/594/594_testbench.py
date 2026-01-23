import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_diff_even_odd(dut):
    """Test diff_even_odd module with various test cases"""
    
    # Test case 1: [1,3,5,7,4,1,6,8] -> diff = 4 - 1 = 3
    dut.list1[0] = 1
    dut.list1[1] = 3
    dut.list1[2] = 5
    dut.list1[3] = 7
    dut.list1[4] = 4
    dut.list1[5] = 1
    dut.list1[6] = 6
    dut.list1[7] = 8
    await Timer(10, units='ns')
    assert dut.diff.value == 3, f"Test 1 failed: expected 3, got {int(dut.diff.value)}"
    print("Test 1 passed: [1,3,5,7,4,1,6,8] -> diff=3")
    
    # Test case 2: [1,2,3,4,5,6,7,8,9,10] -> diff = 2 - 1 = 1
    # Using first 8 elements: [1,2,3,4,5,6,7,8]
    dut.list1[0] = 1
    dut.list1[1] = 2
    dut.list1[2] = 3
    dut.list1[3] = 4
    dut.list1[4] = 5
    dut.list1[5] = 6
    dut.list1[6] = 7
    dut.list1[7] = 8
    await Timer(10, units='ns')
    assert dut.diff.value == 1, f"Test 2 failed: expected 1, got {int(dut.diff.value)}"
    print("Test 2 passed: [1,2,3,4,5,6,7,8] -> diff=1")
    
    # Test case 3: [1,5,7,9,10] -> diff = 10 - 1 = 9
    dut.list1[0] = 1
    dut.list1[1] = 5
    dut.list1[2] = 7
    dut.list1[3] = 9
    dut.list1[4] = 10
    dut.list1[5] = 0
    dut.list1[6] = 0
    dut.list1[7] = 0
    await Timer(10, units='ns')
    assert dut.diff.value == 9, f"Test 3 failed: expected 9, got {int(dut.diff.value)}"
    print("Test 3 passed: [1,5,7,9,10,0,0,0] -> diff=9")
    
    # Test case 4: All even numbers [2,4,6,8,10,12,14,16] -> diff = 2 - (-1) = 3
    # No odd number, first_odd = -1 (0xFF), diff = 2 - (-1) = 3
    dut.list1[0] = 2
    dut.list1[1] = 4
    dut.list1[2] = 6
    dut.list1[3] = 8
    dut.list1[4] = 10
    dut.list1[5] = 12
    dut.list1[6] = 14
    dut.list1[7] = 16
    await Timer(10, units='ns')
    assert dut.diff.value == 3, f"Test 4 failed: expected 3, got {int(dut.diff.value)}"
    print("Test 4 passed: all even -> diff=2 - (-1) = 3")
    
    # Test case 5: All odd numbers [1,3,5,7,9,11,13,15] -> diff = (-1) - 1 = -2
    # No even number, first_even = -1 (0xFF), diff = -1 - 1 = -2
    dut.list1[0] = 1
    dut.list1[1] = 3
    dut.list1[2] = 5
    dut.list1[3] = 7
    dut.list1[4] = 9
    dut.list1[5] = 11
    dut.list1[6] = 13
    dut.list1[7] = 15
    await Timer(10, units='ns')
    assert dut.diff.value == 254, f"Test 5 failed: expected 254 (0xFE), got {int(dut.diff.value)}"
    print("Test 5 passed: all odd -> diff=-1 - 1 = -2 (0xFE)")
    
    # Test case 6: Even at position 0 [2,1,3,5,7,9,11,13] -> diff = 2 - 1 = 1
    dut.list1[0] = 2
    dut.list1[1] = 1
    dut.list1[2] = 3
    dut.list1[3] = 5
    dut.list1[4] = 7
    dut.list1[5] = 9
    dut.list1[6] = 11
    dut.list1[7] = 13
    await Timer(10, units='ns')
    assert dut.diff.value == 1, f"Test 6 failed: expected 1, got {int(dut.diff.value)}"
    print("Test 6 passed: [2,1,...] -> diff=2 - 1 = 1")
    
    # Test case 7: All zeros [0,0,0,0,0,0,0,0] -> diff = 0 - 1 = 255
    # 0 is even, so first_even=0, no odd, first_odd=-1, diff = 0 - (-1) = 1
    # Wait: 0 % 2 == 0, so first_even=0, no odd, first_odd=-1, diff=0-(-1)=1
    dut.list1[0] = 0
    dut.list1[1] = 0
    dut.list1[2] = 0
    dut.list1[3] = 0
    dut.list1[4] = 0
    dut.list1[5] = 0
    dut.list1[6] = 0
    dut.list1[7] = 0
    await Timer(10, units='ns')
    assert dut.diff.value == 1, f"Test 7 failed: expected 1, got {int(dut.diff.value)}"
    print("Test 7 passed: all zeros -> diff=0 - (-1) = 1")
    
    print("
All 7 tests passed!")