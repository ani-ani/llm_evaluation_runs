import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_check_distinct(dut):
    """Test the check_distinct module with various test cases"""
    
    # Test case 1: Has duplicates (indices 0=4 and 1=5 values)
    dut.data_in.value = [1, 4, 5, 6, 1, 4, 0, 0]
    await Timer(1, units='ns')
    if dut.is_distinct.value != 0:
        raise TestFailure(f"Test 1 failed: Expected is_distinct=0, got {dut.is_distinct.value}")
    print("Test 1 passed: Duplicates detected correctly")
    
    # Test case 2: No duplicates (first 4 elements distinct, rest zero)
    dut.data_in.value = [1, 4, 5, 6, 0, 0, 0, 0]
    await Timer(1, units='ns')
    if dut.is_distinct.value != 1:
        raise TestFailure(f"Test 2 failed: Expected is_distinct=1, got {dut.is_distinct.value}")
    print("Test 2 passed: Distinct elements verified")
    
    # Test case 3: All distinct
    dut.data_in.value = [2, 3, 4, 5, 6, 0, 0, 0]
    await Timer(1, units='ns')
    if dut.is_distinct.value != 1:
        raise TestFailure(f"Test 3 failed: Expected is_distinct=1, got {dut.is_distinct.value}")
    print("Test 3 passed: Distinct elements verified")
    
    # Test case 4: All elements same
    dut.data_in.value = [7, 7, 7, 7, 7, 7, 7, 7]
    await Timer(1, units='ns')
    if dut.is_distinct.value != 0:
        raise TestFailure(f"Test 4 failed: Expected is_distinct=0, got {dut.is_distinct.value}")
    print("Test 4 passed: All duplicates detected")
    
    # Test case 5: Edge case - only last element duplicates first
    dut.data_in.value = [1, 2, 3, 4, 5, 6, 7, 1]
    await Timer(1, units='ns')
    if dut.is_distinct.value != 0:
        raise TestFailure(f"Test 5 failed: Expected is_distinct=0, got {dut.is_distinct.value}")
    print("Test 5 passed: Duplicates at ends detected")
    
    # Test case 6: All zeros (should be distinct as all equal values)
    dut.data_in.value = [0, 0, 0, 0, 0, 0, 0, 0]
    await Timer(1, units='ns')
    if dut.is_distinct.value != 0:
        raise TestFailure(f"Test 6 failed: Expected is_distinct=0, got {dut.is_distinct.value}")
    print("Test 6 passed: All zeros treated as duplicates")
    
    passed = 6
    total = 6
    print(f"
{passed}/{total} tests passed")