import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert signed value from 2's complement
def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_pairs_sum_to_zero(dut):
    """Test pairs_sum_to_zero module with various test cases"""
    
    # Define test cases: (data_list, expected_result)
    # Data is list of integers, expected is 0 or 1
    test_cases = [
        ([1, 3, 5, 0], 0),
        ([1, 3, -2, 1], 0),
        ([1, 2, 3, 7], 0),
        ([2, 4, -5, 3, 5, 7], 1),  # 2 + (-5) = -3? Wait, check logic. 2 + (-5) = -3. 4 + (-5) = -1. 3 + (-3) = 0? 3 is not in list. 2 + (-2) = 0? 2 is in list. Ah, wait. Let's re-read example. Example says True. Let's trace: 2, 4, -5, 3, 5, 7. Ah, -5 and 5 are in list. Sum = 0. Expected: 1.
        ([1], 0),
        ([-3, 9, -1, 3, 2, 30], 1),  # -3 + 3 = 0. Expected: 1.
        ([-3, 9, -1, 3, 2, 31], 1),  # -3 + 3 = 0. Expected: 1.
        ([-3, 9, -1, 4, 2, 30], 0),  # No pair sums to 0. Expected: 0.
        ([-3, 9, -1, 4, 2, 31], 0),  # No pair sums to 0. Expected: 0.
        ([0, 0], 1),                  # Edge case: two zeros. 0 + 0 = 0. Expected: 1.
        ([-1, 1], 1),                 # Simple pair. Expected: 1.
        ([10, 20, 30], 0)             # All positive. Expected: 0.
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Starting {total} tests...")
    
    for i, (data_list, expected) in enumerate(test_cases):
        # Fill inputs
        # Max 8 elements per interface spec
        if len(data_list) > 8:
            dut._log.warning(f"Test case {i} has >8 elements, truncating")
            data_list = data_list[:8]
        
        # Set length
        dut.length.value = len(data_list)
        
        # Set data array elements
        # Interface: data_in[0:7], each 8 bits
        # We must initialize all 8 positions even if length is shorter
        # to ensure defined values
        for idx in range(8):
            if idx < len(data_list):
                val = data_list[idx]
                # Handle signed 8-bit representation
                if val < 0:
                    val = (1 << 8) + val
            else:
                val = 0  # Dummy value for unused slots
            
            # Assign to array element
            try:
                dut.data_in[idx].value = val
            except Exception as e:
                raise TestFailure(f"Failed to assign data_in[{idx}]: {e}")
        
        # Wait for combinational propagation
        await Timer(50, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
        
        actual = int(dut.result.value)
        
        if actual != expected:
            raise TestFailure(f"Test {i} Failed: input {data_list}, expected {expected}, got {actual}")
        else:
            passed += 1
            dut._log.info(f"Test {i} Passed: {data_list} -> {actual}")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Some tests failed ({passed}/{total})"
