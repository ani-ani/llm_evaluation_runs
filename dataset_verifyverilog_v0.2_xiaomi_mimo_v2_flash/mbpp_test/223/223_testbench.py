import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_majority_check(dut):
    """Test majority element detection in sorted arrays"""
    
    # Test Case 1: Majority exists (7 elements)
    # arr = [1, 2, 3, 3, 3, 3, 10], n=7, x=3
    dut.n.value = 7
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 3
    dut.arr[4].value = 3
    dut.arr[5].value = 3
    dut.arr[6].value = 10
    dut.arr[7].value = 0  # unused
    dut.x.value = 3
    await Timer(1, units='ns')
    if dut.result.value != 1:
        raise TestFailure(f"Test 1 failed: expected 1, got {dut.result.value}")
    print("Test 1 passed: Majority found [1,2,3,3,3,3,10]")
    
    # Test Case 2: No majority (8 elements)
    # arr = [1, 1, 2, 4, 4, 4, 6, 6], n=8, x=4
    dut.n.value = 8
    dut.arr[0].value = 1
    dut.arr[1].value = 1
    dut.arr[2].value = 2
    dut.arr[3].value = 4
    dut.arr[4].value = 4
    dut.arr[5].value = 4
    dut.arr[6].value = 6
    dut.arr[7].value = 6
    dut.x.value = 4
    await Timer(1, units='ns')
    if dut.result.value != 0:
        raise TestFailure(f"Test 2 failed: expected 0, got {dut.result.value}")
    print("Test 2 passed: No majority [1,1,2,4,4,4,6,6]")
    
    # Test Case 3: Majority exists (5 elements)
    # arr = [1, 1, 1, 2, 2], n=5, x=1
    dut.n.value = 5
    dut.arr[0].value = 1
    dut.arr[1].value = 1
    dut.arr[2].value = 1
    dut.arr[3].value = 2
    dut.arr[4].value = 2
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    dut.x.value = 1
    await Timer(1, units='ns')
    if dut.result.value != 1:
        raise TestFailure(f"Test 3 failed: expected 1, got {dut.result.value}")
    print("Test 3 passed: Majority found [1,1,1,2,2]")
    
    # Test Case 4: Element not majority (4 elements)
    # arr = [1, 1, 2, 2], n=4, x=1
    dut.n.value = 4
    dut.arr[0].value = 1
    dut.arr[1].value = 1
    dut.arr[2].value = 2
    dut.arr[3].value = 2
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    dut.x.value = 1
    await Timer(1, units='ns')
    if dut.result.value != 0:
        raise TestFailure(f"Test 4 failed: expected 0, got {dut.result.value}")
    print("Test 4 passed: No majority [1,1,2,2]")
    
    # Test Case 5: Single element, majority
    # arr = [5], n=1, x=5
    dut.n.value = 1
    dut.arr[0].value = 5
    dut.arr[1].value = 0
    dut.arr[2].value = 0
    dut.arr[3].value = 0
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    dut.x.value = 5
    await Timer(1, units='ns')
    if dut.result.value != 1:
        raise TestFailure(f"Test 5 failed: expected 1, got {dut.result.value}")
    print("Test 5 passed: Single element [5]")
    
    # Test Case 6: Element not in array
    # arr = [1, 2, 3], n=3, x=5
    dut.n.value = 3
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 0
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    dut.x.value = 5
    await Timer(1, units='ns')
    if dut.result.value != 0:
        raise TestFailure(f"Test 6 failed: expected 0, got {dut.result.value}")
    print("Test 6 passed: Element not in array")
    
    # Test Case 7: All elements same (majority)
    # arr = [7, 7, 7, 7], n=4, x=7
    dut.n.value = 4
    dut.arr[0].value = 7
    dut.arr[1].value = 7
    dut.arr[2].value = 7
    dut.arr[3].value = 7
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    dut.x.value = 7
    await Timer(1, units='ns')
    if dut.result.value != 1:
        raise TestFailure(f"Test 7 failed: expected 1, got {dut.result.value}")
    print("Test 7 passed: All same elements")
    
    print(f"
Summary: All tests passed!")