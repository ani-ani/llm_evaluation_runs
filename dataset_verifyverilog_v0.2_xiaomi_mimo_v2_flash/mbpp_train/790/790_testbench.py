import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_even_position(dut):
    """Test even_position module with various test cases"""
    
    # Test case 1: [3,2,1] -> False (3 at index 0 is odd, should be even)
    dut.nums.value = 0x0000000000010203  # [3,2,1,0,0,0,0,0] in little-endian byte array
    await Timer(1, units='ns')
    assert dut.result.value == 0, f"Test 1 failed: expected 0, got {dut.result.value}"
    print("Test 1 passed: [3,2,1] -> False")
    
    # Test case 2: [1,2,3] -> False (1 at index 0 is odd, should be even)
    dut.nums.value = 0x0000000000030201  # [1,2,3,0,0,0,0,0]
    await Timer(1, units='ns')
    assert dut.result.value == 0, f"Test 2 failed: expected 0, got {dut.result.value}"
    print("Test 2 passed: [1,2,3] -> False")
    
    # Test case 3: [2,1,4] -> True (2 even at 0, 1 odd at 1, 4 even at 2)
    dut.nums.value = 0x0000000000040102  # [2,1,4,0,0,0,0,0]
    await Timer(1, units='ns')
    assert dut.result.value == 1, f"Test 3 failed: expected 1, got {dut.result.value}"
    print("Test 3 passed: [2,1,4] -> True")
    
    # Test case 4: All even positions even, all odd positions odd [2,1,4,3,6,5,8,7]
    dut.nums.value = 0x0706050403060102  # [2,1,4,3,6,5,8,7] in little-endian
    await Timer(1, units='ns')
    assert dut.result.value == 1, f"Test 4 failed: expected 1, got {dut.result.value}"
    print("Test 4 passed: [2,1,4,3,6,5,8,7] -> True")
    
    # Test case 5: Empty array (all zeros) -> True (0 is even, matches all even indices)
    dut.nums.value = 0
    await Timer(1, units='ns')
    assert dut.result.value == 1, f"Test 5 failed: expected 1, got {dut.result.value}"
    print("Test 5 passed: [0,0,0,0,0,0,0,0] -> True")
    
    print(f"
Summary: All {5} tests passed!")