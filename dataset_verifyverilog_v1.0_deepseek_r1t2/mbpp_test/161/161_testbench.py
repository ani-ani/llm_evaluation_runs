import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
LEN_WIDTH = 4

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_remove_elements(dut):
    """Test the remove_elements combinational module."""
    
    # Test cases: (list1, list2, expected_result, description)
    test_cases = [
        (
            [1, 2, 3, 4, 5, 6, 7, 8],
            [2, 4, 6, 8],
            [1, 3, 5, 7],
            "Remove evens from 1-8"
        ),
        (
            [1, 2, 3, 4, 5, 6, 7, 8],
            [1, 3, 5, 7],
            [2, 4, 6, 8],
            "Remove odds from 1-8"
        ),
        (
            [1, 2, 3, 4, 5, 6, 7, 8],
            [5, 7],
            [1, 2, 3, 4, 6, 8],
            "Remove 5 and 7"
        ),
        (
            [1, 3, 5, 7, 9, 11, 13, 15],
            [2, 4, 6, 8],
            [1, 3, 5, 7, 9, 11, 13, 15],
            "No elements to remove"
        ),
        (
            [10, 20, 30, 40, 50, 60, 70, 80],
            [10, 20, 30, 40, 50, 60, 70, 80],
            [],
            "Remove all elements"
        ),
        (
            [5, 5, 5, 5, 5, 5, 5, 5],
            [5, 0, 0, 0, 0, 0, 0, 0],
            [],
            "All same, remove value"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (list1, list2, expected, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Calculate expected length
            expected_len = len(expected)
            
            # Write inputs
            dut._log.info(f"  list1 = {list1}")
            dut._log.info(f"  list2 = {list2}")
            
            await write_array(dut, 'list1', list1, DATA_WIDTH)
            await write_array(dut, 'list2', list2, DATA_WIDTH)
            
            # Set lengths
            dut.len1.value = len(list1)
            dut.len2.value = len(list2)
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read outputs
            result_len = None
            if has_signal(dut, 'result_len'):
                if is_value_defined(dut.result_len.value):
                    result_len = int(dut.result_len.value)
            
            result_array = await read_array(dut, 'result', ARRAY_SIZE)
            
            # Validate
            if result_len is None:
                raise TestFailure("result_len is undefined (X/Z)")
            
            if result_len != expected_len:
                raise TestFailure(f"result_len mismatch: expected {expected_len}, got {result_len}")
            
            # Extract valid elements from result
            actual_result = []
            for j in range(result_len):
                if result_array[j] is None:
                    raise TestFailure(f"Result element {j} is undefined")
                actual_result.append(result_array[j])
            
            if actual_result != expected:
                raise TestFailure(f"Result mismatch: expected {expected}, got {actual_result}")
            
            dut._log.info(f"  Result: {actual_result} (len={result_len})")
            dut._log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"Test Summary: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
