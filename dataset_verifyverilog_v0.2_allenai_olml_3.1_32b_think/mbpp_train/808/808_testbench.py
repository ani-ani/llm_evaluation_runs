import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_contains_k(dut):
    """Test tuple contains K functionality"""
    
    # Test 1: K exists in tuple (10, 4, 5, 6, 8), K=6
    dut.k.value = 6
    dut.data[0].value = 10
    dut.data[1].value = 4
    dut.data[2].value = 5
    dut.data[3].value = 6
    dut.data[4].value = 8
    dut.data[5].value = 0
    dut.data[6].value = 0
    dut.data[7].value = 0
    await Timer(1, units='ns')
    assert dut.found.value == 1, f"Test 1 failed: Expected found=1, got {dut.found.value}"
    print("Test 1 passed: (10,4,5,6,8) contains 6")
    
    # Test 2: K does not exist in tuple (1, 2, 3, 4, 5, 6), K=7
    dut.k.value = 7
    dut.data[0].value = 1
    dut.data[1].value = 2
    dut.data[2].value = 3
    dut.data[3].value = 4
    dut.data[4].value = 5
    dut.data[5].value = 6
    dut.data[6].value = 0
    dut.data[7].value = 0
    await Timer(1, units='ns')
    assert dut.found.value == 0, f"Test 2 failed: Expected found=0, got {dut.found.value}"
    print("Test 2 passed: (1,2,3,4,5,6) does not contain 7")
    
    # Test 3: K exists in tuple (7, 8, 9, 44, 11, 12), K=11
    dut.k.value = 11
    dut.data[0].value = 7
    dut.data[1].value = 8
    dut.data[2].value = 9
    dut.data[3].value = 44
    dut.data[4].value = 11
    dut.data[5].value = 12
    dut.data[6].value = 0
    dut.data[7].value = 0
    await Timer(1, units='ns')
    assert dut.found.value == 1, f"Test 3 failed: Expected found=1, got {dut.found.value}"
    print("Test 3 passed: (7,8,9,44,11,12) contains 11")
    
    # Test 4: Edge case - K=0 in array with all zeros
    dut.k.value = 0
    dut.data[0].value = 0
    dut.data[1].value = 0
    dut.data[2].value = 0
    dut.data[3].value = 0
    dut.data[4].value = 0
    dut.data[5].value = 0
    dut.data[6].value = 0
    dut.data[7].value = 0
    await Timer(1, units='ns')
    assert dut.found.value == 1, f"Test 4 failed: Expected found=1, got {dut.found.value}"
    print("Test 4 passed: All zeros contains 0")
    
    # Test 5: Edge case - K at last position
    dut.k.value = 99
    dut.data[0].value = 1
    dut.data[1].value = 2
    dut.data[2].value = 3
    dut.data[3].value = 4
    dut.data[4].value = 5
    dut.data[5].value = 6
    dut.data[6].value = 7
    dut.data[7].value = 99
    await Timer(1, units='ns')
    assert dut.found.value == 1, f"Test 5 failed: Expected found=1, got {dut.found.value}"
    print("Test 5 passed: K at last position found")
    
    # Test 6: Edge case - Maximum value
    dut.k.value = 255
    dut.data[0].value = 255
    dut.data[1].value = 0
    dut.data[2].value = 0
    dut.data[3].value = 0
    dut.data[4].value = 0
    dut.data[5].value = 0
    dut.data[6].value = 0
    dut.data[7].value = 0
    await Timer(1, units='ns')
    assert dut.found.value == 1, f"Test 6 failed: Expected found=1, got {dut.found.value}"
    print("Test 6 passed: Max value (255) found")
    
    print(f"
All tests passed!")