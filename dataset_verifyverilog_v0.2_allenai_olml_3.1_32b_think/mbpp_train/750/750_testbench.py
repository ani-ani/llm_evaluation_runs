import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_add_tuple(dut):
    """Test add_tuple module with various combinations"""
    
    # Test case 1: [5, 6, 7] + (9, 10) = [5, 6, 7, 9, 10]
    dut.list_in.value = [5, 6, 7, 0]  # 4 elements
    dut.tuple_in.value = [9, 10]  # 2 elements
    await Timer(10, units='ns')
    result = [int(x) for x in dut.result.value]
    expected = [5, 6, 7, 0, 9, 10]
    if result != expected:
        raise TestFailure(f"Test 1 failed: got {result}, expected {expected}")
    print(f"Test 1 passed: [5,6,7,0] + [9,10] = {result}")
    
    # Test case 2: [6, 7, 8] + (10, 11) = [6, 7, 8, 10, 11]
    dut.list_in.value = [6, 7, 8, 0]
    dut.tuple_in.value = [10, 11]
    await Timer(10, units='ns')
    result = [int(x) for x in dut.result.value]
    expected = [6, 7, 8, 0, 10, 11]
    if result != expected:
        raise TestFailure(f"Test 2 failed: got {result}, expected {expected}")
    print(f"Test 2 passed: [6,7,8,0] + [10,11] = {result}")
    
    # Test case 3: [7, 8, 9] + (11, 12) = [7, 8, 9, 11, 12]
    dut.list_in.value = [7, 8, 9, 0]
    dut.tuple_in.value = [11, 12]
    await Timer(10, units='ns')
    result = [int(x) for x in dut.result.value]
    expected = [7, 8, 9, 0, 11, 12]
    if result != expected:
        raise TestFailure(f"Test 3 failed: got {result}, expected {expected}")
    print(f"Test 3 passed: [7,8,9,0] + [11,12] = {result}")
    
    # Test case 4: Edge case with all elements used
    dut.list_in.value = [1, 2, 3, 4]
    dut.tuple_in.value = [255, 254]
    await Timer(10, units='ns')
    result = [int(x) for x in dut.result.value]
    expected = [1, 2, 3, 4, 255, 254]
    if result != expected:
        raise TestFailure(f"Test 4 failed: got {result}, expected {expected}")
    print(f"Test 4 passed: [1,2,3,4] + [255,254] = {result}")
    
    # Test case 5: Zero values
    dut.list_in.value = [0, 0, 0, 0]
    dut.tuple_in.value = [0, 0]
    await Timer(10, units='ns')
    result = [int(x) for x in dut.result.value]
    expected = [0, 0, 0, 0, 0, 0]
    if result != expected:
        raise TestFailure(f"Test 5 failed: got {result}, expected {expected}")
    print(f"Test 5 passed: [0,0,0,0] + [0,0] = {result}")
    
    print("
All 5 tests passed!")