import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_LEN = 3

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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_even_position(dut):
    """Test even_position_check module."""
    
    # Wait for combinational logic to settle
    await Timer(100, units='ns')
    
    # Test cases: (arr_values, len, expected_result, description)
    test_cases = [
        ([3, 2, 1], 3, 0, "Test 1: [3,2,1] - index 0 odd vs even, fails"),
        ([1, 2, 3], 3, 0, "Test 2: [1,2,3] - index 0 odd vs even, fails"),
        ([2, 1, 4], 3, 1, "Test 3: [2,1,4] - all correct parity"),
        ([2, 1], 2, 1, "Additional: [2,1] - first two correct"),
        ([2], 1, 1, "Additional: [2] - single even at index 0"),
        ([1], 1, 0, "Additional: [1] - single odd at index 0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_values, arr_len, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            if has_signal(dut, 'arr_0'):
                dut.arr_0.value = arr_values[0]
                if arr_len >= 2:
                    dut.arr_1.value = arr_values[1]
                if arr_len >= 3:
                    dut.arr_2.value = arr_values[2]
            elif has_signal(dut, 'arr'):
                for idx, val in enumerate(arr_values):
                    dut.arr[idx].value = val
            
            # Write length
            if has_signal(dut, 'len'):
                dut.len.value = arr_len
            else:
                # If no len signal, assume full length
                pass
            
            # Wait for propagation
            await Timer(50, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")