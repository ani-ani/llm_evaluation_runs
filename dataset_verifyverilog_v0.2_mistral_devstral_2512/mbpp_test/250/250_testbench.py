import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_element_counter(dut):
    """Test element counting in array"""
    
    # Test 1: Count element not in array (should be 0)
    dut.target.value = 4
    dut.data_array.value = [10, 8, 5, 2, 10, 15, 10, 8, 5, 8, 8, 2]
    await Timer(10, units='ns')
    count = int(dut.count.value)
    if count != 0:
        raise TestFailure(f"Test 1 failed: expected 0, got {count}")
    print("Test 1 passed: target=4, count=0")
    
    # Test 2: Count occurrences of 10 (should be 3)
    dut.target.value = 10
    dut.data_array.value = [10, 8, 5, 2, 10, 15, 10, 8, 5, 8, 8, 2]
    await Timer(10, units='ns')
    count = int(dut.count.value)
    if count != 3:
        raise TestFailure(f"Test 2 failed: expected 3, got {count}")
    print("Test 2 passed: target=10, count=3")
    
    # Test 3: Count occurrences of 8 (should be 4)
    dut.target.value = 8
    dut.data_array.value = [10, 8, 5, 2, 10, 15, 10, 8, 5, 8, 8, 2]
    await Timer(10, units='ns')
    count = int(dut.count.value)
    if count != 4:
        raise TestFailure(f"Test 3 failed: expected 4, got {count}")
    print("Test 3 passed: target=8, count=4")
    
    # Test 4: Count occurrences of 2 (should be 2)
    dut.target.value = 2
    dut.data_array.value = [10, 8, 5, 2, 10, 15, 10, 8, 5, 8, 8, 2]
    await Timer(10, units='ns')
    count = int(dut.count.value)
    if count != 2:
        raise TestFailure(f"Test 4 failed: expected 2, got {count}")
    print("Test 4 passed: target=2, count=2")
    
    # Test 5: Count occurrences of 15 (should be 1)
    dut.target.value = 15
    dut.data_array.value = [10, 8, 5, 2, 10, 15, 10, 8, 5, 8, 8, 2]
    await Timer(10, units='ns')
    count = int(dut.count.value)
    if count != 1:
        raise TestFailure(f"Test 5 failed: expected 1, got {count}")
    print("Test 5 passed: target=15, count=1")
    
    print("All 5 tests passed!")