import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_filter_integers_basic(dut):
    """Test basic integer filtering"""
    
    # Test case 1: Empty filter scenario - all non-integers
    # In our adapted format: values 256-511 represent non-integers
    # We'll use values 300, 400, etc. as non-integers
    
    # Test case 1: Mixed values [4, 300, 350, 23, 9, 400, 500, 200]
    # Expected: [4, 23, 9, 200, 0, 0, 0, 0], count=4
    test_values = [4, 300, 350, 23, 9, 400, 500, 200]
    expected_result = [4, 23, 9, 200, 0, 0, 0, 0]
    expected_count = 4
    
    # Set input array values
    for i in range(8):
        dut.arr[i].value = test_values[i]
    
    # Wait for combinational logic to propagate
    await Timer(100, units='ns')
    
    # Check outputs
    for i in range(8):
        if not is_value_defined(dut.result[i].value):
            raise TestFailure(f"Result[{i}] is undefined")
        
        result_val = int(dut.result[i].value)
        if result_val != expected_result[i]:
            raise TestFailure(f"Test 1: result[{i}] expected {expected_result[i]}, got {result_val}")
    
    if not is_value_defined(dut.count.value):
        raise TestFailure("Count is undefined")
    
    count_val = int(dut.count.value)
    if count_val != expected_count:
        raise TestFailure(f"Test 1: count expected {expected_count}, got {count_val}")
    
    dut._log.info(f"Test 1 passed: filtered {count_val} integers")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_filter_integers_all_integers(dut):
    """Test with all integers"""
    
    # Test case 2: All integers [1, 2, 3, 10, 20, 30, 100, 255]
    test_values = [1, 2, 3, 10, 20, 30, 100, 255]
    expected_result = [1, 2, 3, 10, 20, 30, 100, 255]
    expected_count = 8
    
    for i in range(8):
        dut.arr[i].value = test_values[i]
    
    await Timer(100, units='ns')
    
    for i in range(8):
        if not is_value_defined(dut.result[i].value):
            raise TestFailure(f"Result[{i}] is undefined")
        
        result_val = int(dut.result[i].value)
        if result_val != expected_result[i]:
            raise TestFailure(f"Test 2: result[{i}] expected {expected_result[i]}, got {result_val}")
    
    if not is_value_defined(dut.count.value):
        raise TestFailure("Count is undefined")
    
    count_val = int(dut.count.value)
    if count_val != expected_count:
        raise TestFailure(f"Test 2: count expected {expected_count}, got {count_val}")
    
    dut._log.info(f"Test 2 passed: found all {count_val} integers")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_filter_integers_no_integers(dut):
    """Test with no integers"""
    
    # Test case 3: No integers [300, 400, 500, 600, 700, 800, 900, 1000]
    test_values = [300, 400, 500, 600, 700, 800, 900, 1000]
    expected_result = [0, 0, 0, 0, 0, 0, 0, 0]
    expected_count = 0
    
    for i in range(8):
        dut.arr[i].value = test_values[i]
    
    await Timer(100, units='ns')
    
    for i in range(8):
        if not is_value_defined(dut.result[i].value):
            raise TestFailure(f"Result[{i}] is undefined")
        
        result_val = int(dut.result[i].value)
        if result_val != expected_result[i]:
            raise TestFailure(f"Test 3: result[{i}] expected {expected_result[i]}, got {result_val}")
    
    if not is_value_defined(dut.count.value):
        raise TestFailure("Count is undefined")
    
    count_val = int(dut.count.value)
    if count_val != expected_count:
        raise TestFailure(f"Test 3: count expected {expected_count}, got {count_val}")
    
    dut._log.info(f"Test 3 passed: found {count_val} integers")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_filter_integers_empty_case(dut):
    """Test with all zeros (edge case)"""
    
    # Test case 4: All zeros [0, 0, 0, 0, 0, 0, 0, 0]
    # Note: 0 is treated as an integer in our adaptation
    test_values = [0, 0, 0, 0, 0, 0, 0, 0]
    expected_result = [0, 0, 0, 0, 0, 0, 0, 0]
    expected_count = 8
    
    for i in range(8):
        dut.arr[i].value = test_values[i]
    
    await Timer(100, units='ns')
    
    for i in range(8):
        if not is_value_defined(dut.result[i].value):
            raise TestFailure(f"Result[{i}] is undefined")
        
        result_val = int(dut.result[i].value)
        if result_val != expected_result[i]:
            raise TestFailure(f"Test 4: result[{i}] expected {expected_result[i]}, got {result_val}")
    
    if not is_value_defined(dut.count.value):
        raise TestFailure("Count is undefined")
    
    count_val = int(dut.count.value)
    if count_val != expected_count:
        raise TestFailure(f"Test 4: count expected {expected_count}, got {count_val}")
    
    dut._log.info(f"Test 4 passed: found {count_val} integers")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_filter_integers_consecutive(dut):
    """Test with consecutive integers at start and non-integers at end"""
    
    # Test case 5: [1, 2, 3, 4, 500, 600, 700, 800]
    # Expected: [1, 2, 3, 4, 0, 0, 0, 0], count=4
    test_values = [1, 2, 3, 4, 500, 600, 700, 800]
    expected_result = [1, 2, 3, 4, 0, 0, 0, 0]
    expected_count = 4
    
    for i in range(8):
        dut.arr[i].value = test_values[i]
    
    await Timer(100, units='ns')
    
    for i in range(8):
        if not is_value_defined(dut.result[i].value):
            raise TestFailure(f"Result[{i}] is undefined")
        
        result_val = int(dut.result[i].value)
        if result_val != expected_result[i]:
            raise TestFailure(f"Test 5: result[{i}] expected {expected_result[i]}, got {result_val}")
    
    if not is_value_defined(dut.count.value):
        raise TestFailure("Count is undefined")
    
    count_val = int(dut.count.value)
    if count_val != expected_count:
        raise TestFailure(f"Test 5: count expected {expected_count}, got {count_val}")
    
    dut._log.info(f"Test 5 passed: found {count_val} integers")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_filter_integers_spread(dut):
    """Test with integers spread throughout array"""
    
    # Test case 6: [300, 5, 400, 10, 500, 15, 600, 20]
    # Expected: [5, 10, 15, 20, 0, 0, 0, 0], count=4
    test_values = [300, 5, 400, 10, 500, 15, 600, 20]
    expected_result = [5, 10, 15, 20, 0, 0, 0, 0]
    expected_count = 4
    
    for i in range(8):
        dut.arr[i].value = test_values[i]
    
    await Timer(100, units='ns')
    
    for i in range(8):
        if not is_value_defined(dut.result[i].value):
            raise TestFailure(f"Result[{i}] is undefined")
        
        result_val = int(dut.result[i].value)
        if result_val != expected_result[i]:
            raise TestFailure(f"Test 6: result[{i}] expected {expected_result[i]}, got {result_val}")
    
    if not is_value_defined(dut.count.value):
        raise TestFailure("Count is undefined")
    
    count_val = int(dut.count.value)
    if count_val != expected_count:
        raise TestFailure(f"Test 6: count expected {expected_count}, got {count_val}")
    
    dut._log.info(f"Test 6 passed: found {count_val} integers")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_filter_integers_zero_and_max(dut):
    """Test with zero and maximum values"""
    
    # Test case 7: [0, 255, 300, 0, 255, 400, 0, 255]
    # Expected: [0, 255, 0, 255, 0, 255, 0, 0], count=6
    test_values = [0, 255, 300, 0, 255, 400, 0, 255]
    expected_result = [0, 255, 0, 255, 0, 255, 0, 0]
    expected_count = 6
    
    for i in range(8):
        dut.arr[i].value = test_values[i]
    
    await Timer(100, units='ns')
    
    for i in range(8):
        if not is_value_defined(dut.result[i].value):
            raise TestFailure(f"Result[{i}] is undefined")
        
        result_val = int(dut.result[i].value)
        if result_val != expected_result[i]:
            raise TestFailure(f"Test 7: result[{i}] expected {expected_result[i]}, got {result_val}")
    
    if not is_value_defined(dut.count.value):
        raise TestFailure("Count is undefined")
    
    count_val = int(dut.count.value)
    if count_val != expected_count:
        raise TestFailure(f"Test 7: count expected {expected_count}, got {count_val}")
    
    dut._log.info(f"Test 7 passed: found {count_val} integers")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_filter_integers_detailed(dut):
    """Detailed test with specific pattern from original problem"""
    
    # Test case 8: Adapted from [4, {}, [], 23.2, 9, 'adasd'] = [4, 9]
    # In our format: 4, 9 are integers; others represented as non-integers
    # Pattern: [4, 300, 350, 400, 9, 500, 600, 700]
    test_values = [4, 300, 350, 400, 9, 500, 600, 700]
    expected_result = [4, 9, 0, 0, 0, 0, 0, 0]
    expected_count = 2
    
    for i in range(8):
        dut.arr[i].value = test_values[i]
    
    await Timer(100, units='ns')
    
    for i in range(8):
        if not is_value_defined(dut.result[i].value):
            raise TestFailure(f"Result[{i}] is undefined")
        
        result_val = int(dut.result[i].value)
        if result_val != expected_result[i]:
            raise TestFailure(f"Test 8: result[{i}] expected {expected_result[i]}, got {result_val}")
    
    if not is_value_defined(dut.count.value):
        raise TestFailure("Count is undefined")
    
    count_val = int(dut.count.value)
    if count_val != expected_count:
        raise TestFailure(f"Test 8: count expected {expected_count}, got {count_val}")
    
    dut._log.info(f"Test 8 passed: filtered correctly")
    dut._log.info("All tests passed!")
