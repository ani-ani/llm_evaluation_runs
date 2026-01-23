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

def to_signed(val, bits=8):
    """Convert unsigned to signed representation."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits=8):
    """Convert signed to unsigned for assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def python_monotonic(arr):
    """Python reference implementation."""
    if len(arr) <= 1:
        return True
    
    # Check if increasing
    increasing = True
    for i in range(1, len(arr)):
        if arr[i] < arr[i-1]:
            increasing = False
            break
    
    if increasing:
        return True
    
    # Check if decreasing
    decreasing = True
    for i in range(1, len(arr)):
        if arr[i] > arr[i-1]:
            decreasing = False
            break
    
    return decreasing

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_monotonic(dut):
    """Test monotonic checker with various cases."""
    
    # Test cases: (name, array_values, expected_result)
    # Note: arrays are padded to 8 elements with 0s if shorter
    test_cases = [
        ("increasing_4", [1, 2, 4, 10, 0, 0, 0, 0], True),
        ("increasing_6", [1, 2, 4, 20, 0, 0, 0, 0], True),
        ("not_monotonic", [1, 20, 4, 10, 0, 0, 0, 0], False),
        ("decreasing_4", [4, 1, 0, -10, 0, 0, 0, 0], True),
        ("equal_values", [4, 1, 1, 0, 0, 0, 0, 0], True),
        ("not_monotonic_6", [1, 2, 3, 2, 5, 60, 0, 0], False),
        ("increasing_6_full", [1, 2, 3, 4, 5, 60, 0, 0], True),
        ("all_equal", [9, 9, 9, 9, 9, 9, 9, 9], True),
        ("single_peak", [1, 5, 10, 8, 7, 6, 5, 4], False),
        ("single_valley", [10, 8, 6, 3, 1, 0, -1, -2], True),
        ("constant", [5, 5, 5, 5, 5, 5, 5, 5], True),
        ("increasing_all", [1, 2, 3, 4, 5, 6, 7, 8], True),
        ("decreasing_all", [8, 7, 6, 5, 4, 3, 2, 1], True),
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (name, arr, expected) in enumerate(test_cases):
        # Assign values to dut array
        for j in range(8):
            val = from_signed(arr[j])
            dut.numbers[j].value = val
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i} ({name}): Result is undefined (X/Z)")
        
        actual = int(dut.result.value)
        
        # Verify with Python reference
        expected_python = python_monotonic(arr[:4] if arr[4] == 0 and arr[5] == 0 else arr)
        
        if actual != expected:
            raise TestFailure(f"Test {i} ({name}): expected {expected}, got {actual}")
        
        if actual != expected_python:
            dut._log.warning(f"Test {i}: HDL result {actual} != Python result {expected_python}")
        
        dut._log.info(f"Test {i} ({name}): PASS")
        passed += 1
    
    dut._log.info(f"\nResults: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
