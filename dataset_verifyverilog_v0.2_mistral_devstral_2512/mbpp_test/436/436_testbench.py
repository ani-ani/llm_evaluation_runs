import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_neg_nos(dut):
    """Test negative number filtering"""
    
    # Test 1: [-1, 4, 5, -6] should find [-1, -6]
    dut.list_in.value = [255, 4, 5, 250]  # -1=0xFF, -6=0xFA
    await Timer(1, units='ns')
    result = [int(x) for x in dut.result.value]
    count = int(dut.count.value)
    
    # Expected: [-1, -6] followed by [0, 0]
    expected_result = [255, 250, 0, 0]
    expected_count = 2
    
    if result != expected_result:
        raise TestFailure(f"Test 1 Failed: Expected {expected_result}, got {result}")
    if count != expected_count:
        raise TestFailure(f"Test 1 Failed: Expected count {expected_count}, got {count}")
    print(f"Test 1 Passed: Input=[-1,4,5,-6], Output={result}, Count={count}")
    
    # Test 2: [-1, -2, 3, 4] should find [-1, -2]
    dut.list_in.value = [255, 254, 3, 4]  # -1=0xFF, -2=0xFE
    await Timer(1, units='ns')
    result = [int(x) for x in dut.result.value]
    count = int(dut.count.value)
    expected_result = [255, 254, 0, 0]
    expected_count = 2
    
    if result != expected_result:
        raise TestFailure(f"Test 2 Failed: Expected {expected_result}, got {result}")
    if count != expected_count:
        raise TestFailure(f"Test 2 Failed: Expected count {expected_count}, got {count}")
    print(f"Test 2 Passed: Input=[-1,-2,3,4], Output={result}, Count={count}")
    
    # Test 3: [-7, -6, 8, 9] should find [-7, -6]
    dut.list_in.value = [249, 250, 8, 9]  # -7=0xF9, -6=0xFA
    await Timer(1, units='ns')
    result = [int(x) for x in dut.result.value]
    count = int(dut.count.value)
    expected_result = [249, 250, 0, 0]
    expected_count = 2
    
    if result != expected_result:
        raise TestFailure(f"Test 3 Failed: Expected {expected_result}, got {result}")
    if count != expected_count:
        raise TestFailure(f"Test 3 Failed: Expected count {expected_count}, got {count}")
    print(f"Test 3 Passed: Input=[-7,-6,8,9], Output={result}, Count={count}")
    
    # Test 4: All positive [1,2,3,4] should find none
    dut.list_in.value = [1, 2, 3, 4]
    await Timer(1, units='ns')
    result = [int(x) for x in dut.result.value]
    count = int(dut.count.value)
    expected_result = [0, 0, 0, 0]
    expected_count = 0
    
    if result != expected_result:
        raise TestFailure(f"Test 4 Failed: Expected {expected_result}, got {result}")
    if count != expected_count:
        raise TestFailure(f"Test 4 Failed: Expected count {expected_count}, got {count}")
    print(f"Test 4 Passed: Input=[1,2,3,4], Output={result}, Count={count}")
    
    # Test 5: All negative [-1,-2,-3,-4] should find all 4
    dut.list_in.value = [255, 254, 253, 252]
    await Timer(1, units='ns')
    result = [int(x) for x in dut.result.value]
    count = int(dut.count.value)
    expected_result = [255, 254, 253, 252]
    expected_count = 4
    
    if result != expected_result:
        raise TestFailure(f"Test 5 Failed: Expected {expected_result}, got {result}")
    if count != expected_count:
        raise TestFailure(f"Test 5 Failed: Expected count {expected_count}, got {count}")
    print(f"Test 5 Passed: Input=[-1,-2,-3,-4], Output={result}, Count={count}")
    
    print("
All 5/5 tests passed!")