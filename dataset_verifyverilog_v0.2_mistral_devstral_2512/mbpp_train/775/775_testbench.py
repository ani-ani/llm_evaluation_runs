import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_odd_position(dut):
    """Test odd_position module with various test cases"""
    
    # Test case 1: [2,1,4,3,6,7,6,3] - All positions valid, length=8
    dut.data[0].value = 2   # pos 0 - even
    dut.data[1].value = 1   # pos 1 - odd
    dut.data[2].value = 4   # pos 2 - even
    dut.data[3].value = 3   # pos 3 - odd
    dut.data[4].value = 6   # pos 4 - even
    dut.data[5].value = 7   # pos 5 - odd
    dut.data[6].value = 6   # pos 6 - even
    dut.data[7].value = 3   # pos 7 - odd
    dut.length.value = 8
    
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 1 failed: expected 1, got {dut.result.value}"
    print("Test 1 passed: [2,1,4,3,6,7,6,3] length=8")
    
    # Test case 2: [4,1,2] - All positions valid, length=3
    dut.data[0].value = 4   # pos 0 - even
    dut.data[1].value = 1   # pos 1 - odd
    dut.data[2].value = 2   # pos 2 - even
    dut.length.value = 3
    
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 2 failed: expected 1, got {dut.result.value}"
    print("Test 2 passed: [4,1,2] length=3")
    
    # Test case 3: [1,2,3] - pos0 should be even but is odd, length=3
    dut.data[0].value = 1   # pos 0 - should be even, but is odd
    dut.data[1].value = 2   # pos 1 - should be odd, but is even
    dut.data[2].value = 3   # pos 2 - even
    dut.length.value = 3
    
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 3 failed: expected 0, got {dut.result.value}"
    print("Test 3 passed: [1,2,3] length=3")
    
    # Test case 4: Single element, even number at position 0
    dut.data[0].value = 8
    dut.length.value = 1
    
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 4 failed: expected 1, got {dut.result.value}"
    print("Test 4 passed: [8] length=1")
    
    # Test case 5: Single element, odd number at position 0 (should fail)
    dut.data[0].value = 5
    dut.length.value = 1
    
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 5 failed: expected 0, got {dut.result.value}"
    print("Test 5 passed: [5] length=1")
    
    # Test case 6: Two elements, valid
    dut.data[0].value = 10  # even
    dut.data[1].value = 11  # odd
    dut.length.value = 2
    
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 6 failed: expected 1, got {dut.result.value}"
    print("Test 6 passed: [10,11] length=2")
    
    print("
All tests completed!")
    print(f"Total tests: 6, Passed: 6")