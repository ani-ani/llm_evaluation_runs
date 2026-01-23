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

async def wait_for_valid_output(dut, timeout_ns=1000):
    """Wait for combinational output to be valid."""
    elapsed = 0
    while elapsed < timeout_ns:
        await Timer(10, units='ns')
        elapsed += 10
        # Check if result array is defined
        all_defined = True
        try:
            # Check count first
            _ = int(dut.count.value)
            # Check all result elements
            for i in range(5):
                _ = int(dut.result[i].value)
        except ValueError:
            all_defined = False
        if all_defined:
            return True
    raise TestFailure(f"Timeout: output not valid after {timeout_ns}ns")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_generate_integers(dut):
    """Test generate_integers module."""
    
    # Test cases: (a, b, expected_count, expected_result_list)
    test_cases = [
        (2, 10, 4, [2, 4, 6, 8]),     # Test 1: 2 to 10
        (10, 2, 4, [2, 4, 6, 8]),     # Test 2: reversed range
        (132, 2, 5, [0, 2, 4, 6, 8]), # Test 3: 2 to 132
        (17, 89, 0, []),              # Test 4: no even digits in range
        (0, 0, 1, [0]),               # Edge case: single number 0
        (8, 8, 1, [8]),               # Edge case: single number 8
        (0, 8, 5, [0, 2, 4, 6, 8]),   # Edge case: 0 to 8
        (100, 200, 0, []),            # Edge case: no digits in range
        (9, 9, 0, []),                # Edge case: odd number only
        (0, 255, 5, [0, 2, 4, 6, 8]), # Edge case: max range
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (a, b, expected_count, expected_list) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: a={a}, b={b}")
        
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        
        # Wait for combinational logic to propagate
        await wait_for_valid_output(dut, timeout_ns=500)
        
        # Read outputs
        if not is_value_defined(dut.count.value):
            raise TestFailure(f"Test {i+1}: count is undefined (X/Z)")
        
        actual_count = int(dut.count.value)
        
        # Verify count
        if actual_count != expected_count:
            dut._log.error(f"Test {i+1} FAILED: count mismatch")
            dut._log.error(f"  Expected: {expected_count}")
            dut._log.error(f"  Got: {actual_count}")
            continue
        
        # Read result array
        actual_list = []
        for j in range(5):
            if not is_value_defined(dut.result[j].value):
                raise TestFailure(f"Test {i+1}: result[{j}] is undefined")
            val = int(dut.result[j].value)
            if j < actual_count:
                actual_list.append(val)
        
        # Verify results
        if actual_list != expected_list:
            dut._log.error(f"Test {i+1} FAILED: result mismatch")
            dut._log.error(f"  Expected: {expected_list}")
            dut._log.error(f"  Got: {actual_list}")
            continue
        
        dut._log.info(f"Test {i+1} PASSED: count={actual_count}, result={actual_list}")
        passed += 1
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
