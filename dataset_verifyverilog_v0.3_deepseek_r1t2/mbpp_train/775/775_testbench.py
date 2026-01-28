import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
MAX_LEN = 8

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def compute_expected(arr, length):
    """Compute expected result in Python."""
    if length == 0:
        return 1
    for i in range(length):
        num = arr[i]
        if i % 2 == 0:  # even index
            if num % 2 != 0:  # should be even
                return 0
        else:  # odd index
            if num % 2 != 1:  # should be odd
                return 0
    return 1

# ============================================================================
# ARRAY WRITE HELPER
# ============================================================================

async def write_array_and_len(dut, arr_values, length):
    """Write array elements and length to DUT."""
    # Write array elements
    for i in range(ARRAY_SIZE):
        if i < length:
            dut.arr[i].value = clamp_to_width(arr_values[i], DATA_WIDTH)
        else:
            dut.arr[i].value = 0  # Initialize unused elements
    
    # Write length
    if has_signal(dut, 'len'):
        dut.len.value = length
    else:
        # Try alternative port names
        for port in ['length', 'num_elements', 'size']:
            if has_signal(dut, port):
                getattr(dut, port).value = length
                break

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_odd_position_checker(dut):
    """Test odd position checker with various test cases."""
    
    cocotb.log.info("=" * 60)
    cocotb.log.info("Testing Odd Position Checker")
    cocotb.log.info("=" * 60)
    
    # Verify required signals exist
    if not has_signal(dut, 'arr'):
        raise TestFailure("DUT missing required 'arr' signal")
    if not has_signal(dut, 'result'):
        raise TestFailure("DUT missing required 'result' signal")
    
    # Test cases from problem
    test_cases = [
        ([2,1,4,3,6,7,6,3], 8, 1, "Original test case 1"),
        ([4,1,2], 3, 1, "Original test case 2"),
        ([1,2,3], 3, 0, "Original test case 3"),
    ]
    
    # Additional edge cases
    test_cases.extend([
        ([], 0, 1, "Empty array"),
        ([0], 1, 1, "Single even at index 0"),
        ([1], 1, 1, "Single odd at index 0"),
        ([2,5], 2, 1, "Two elements: even,odd"),
        ([1,4], 2, 0, "Two elements: odd,even (fail)"),
        ([0,1,2,3,4,5,6,7], 8, 1, "All even/odd mixed"),
        ([0,0,0,0,0,0,0,0], 8, 1, "All zeros (even)"),
        ([1,1,1,1,1,1,1,1], 8, 0, "All ones (fail at even indices)"),
    ])
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, length, expected, description) in enumerate(test_cases, 1):
        cocotb.log.info(f"\nTest {i}: {description}")
        cocotb.log.info(f"  Input: arr={arr_vals[:length]}, len={length}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write inputs
            await write_array_and_len(dut, arr_vals, length)
            
            # Wait for combinational propagation
            await Timer(50, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            actual = int(dut.result.value)
            
            # Verify
            if actual != expected:
                raise TestFailure(f"Expected {expected}, got {actual}")
            
            cocotb.log.info(f"  Result: {actual} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  [FAIL] {e}")
            failed += 1
    
    # Additional random tests
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info("Running random tests...")
    
    for test_num in range(10):
        length = random.randint(0, MAX_LEN)
        arr_vals = [random.randint(0, 255) for _ in range(length)]
        expected = compute_expected(arr_vals, length)
        
        try:
            await write_array_and_len(dut, arr_vals, length)
            await Timer(50, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            actual = int(dut.result.value)
            
            if actual != expected:
                raise TestFailure(f"Random test failed: arr={arr_vals}, len={length}, expected={expected}, got={actual}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Random test {test_num+1} failed: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info("All tests passed!")