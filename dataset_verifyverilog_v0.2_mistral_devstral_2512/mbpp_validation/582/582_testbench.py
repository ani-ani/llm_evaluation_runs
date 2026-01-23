import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_dict_empty_check(dut):
    """Test dictionary emptiness check functionality"""
    
    # Test 1: Non-empty dictionary (is_empty = 0) should return False (0)
    dut.is_empty.value = 0
    await Timer(10, units='ns')
    if dut.result.value != 0:
        raise TestFailure(f"Test 1 failed: Expected result=0 for non-empty dict, got {dut.result.value}")
    print("Test 1 passed: Non-empty dict returns False")
    
    # Test 2: Another non-empty dictionary (is_empty = 0) should return False (0)
    dut.is_empty.value = 0
    await Timer(10, units='ns')
    if dut.result.value != 0:
        raise TestFailure(f"Test 2 failed: Expected result=0 for non-empty dict, got {dut.result.value}")
    print("Test 2 passed: Non-empty dict returns False")
    
    # Test 3: Empty dictionary (is_empty = 1) should return True (1)
    dut.is_empty.value = 1
    await Timer(10, units='ns')
    if dut.result.value != 1:
        raise TestFailure(f"Test 3 failed: Expected result=1 for empty dict, got {dut.result.value}")
    print("Test 3 passed: Empty dict returns True")
    
    print("
Summary: 3/3 tests passed")