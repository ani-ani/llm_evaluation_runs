import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert list to expected result
def check_sorted_logic(arr):
    if not arr:
        return True
    
    # Count drops (arr[i] > arr[i+1])
    drops = 0
    for i in range(len(arr) - 1):
        if arr[i] > arr[i+1]:
            drops += 1
    
    # Check boundary
    boundary_violation = 1 if arr[-1] > arr[0] else 0
    
    # Logic: (drops == 0) OR (drops == 1 AND boundary_violation == 0)
    if drops == 0:
        return True
    elif drops == 1 and boundary_violation == 0:
        return True
    else:
        return False

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_move_one_ball(dut):
    """Test move_one_ball module against various array configurations."""
    
    # Test cases: (input_array, expected_result)
    test_cases = [
        ([3, 4, 5, 1, 2], True),   # Single drop, valid rotation
        ([3, 5, 10, 1, 2], True),  # Single drop, valid rotation
        ([4, 3, 1, 2], False),     # Multiple drops (4>3, 3>1, but 1<2) - actually drops=2 -> False
        ([3, 5, 4, 1, 2], False),  # Multiple drops
        ([], True),                # Empty array (handled by logic: 0 drops)
        ([1, 2, 3, 4], True),      # Already sorted
        ([4, 1, 2, 3], True),      # Single drop at end
        ([1, 3, 2, 4], False),     # Drop in middle
    ]
    
    # We adapt to 8-element arrays by padding with 0s or extending if needed
    # But Python list logic needs to match Verilog 8-element requirement.
    # The Verilog module expects 8 elements.
    
    passed = 0
    total = len(test_cases)
    
    for i, (py_arr, expected) in enumerate(test_cases):
        # Adapt array to 8 elements (padding with 0s at the end if needed)
        # Note: Padding with 0s might affect logic if 0 is smaller than other elements.
        # However, the problem logic assumes unique elements.
        # To keep it safe, we should pad with values that don't interfere.
        # Or, since the problem implies unique elements, let's pad with large values 
        # (or just handle the array size).
        # The Verilog spec says 8 elements. The test cases in Python are variable length.
        # We will pad the Python list to length 8 with values that maintain the property.
        
        # Strategy: Pad with a value larger than any existing value to ensure no new drops
        # are introduced if the array is already a valid rotation.
        # Or simpler: Just verify the logic on the actual elements provided, and 
        # ensure the Verilog module sees the same logic.
        # Since Verilog module processes exactly 8 elements, we must provide 8.
        
        # Let's pad the Python test array to 8 elements using a sentinel value.
        # But wait, if we pad with large values, say 255:
        # [3, 4, 5, 1, 2] -> [3, 4, 5, 1, 2, 255, 255, 255]
        # Drops: 5<1 (no), 1<2 (no), 2<255 (no). Drops=0. 
        # But boundary: 255 > 3 -> boundary_violation=1. 
        # Logic: (drops=0) -> True. Correct.
        
        # [4, 3, 1, 2] -> [4, 3, 1, 2, 255, 255, 255, 255]
        # Drops: 4>3 (1), 3>1 (2), 1<2 (2). Drops=2 -> False. Correct.
        
        # [1, 2, 3, 4] -> [1, 2, 3, 4, 255, 255, 255, 255]
        # Drops: 3<4 (0), 4<255 (0). Drops=0. Boundary: 255>1 (1).
        # Logic: (drops=0) -> True. Correct.
        
        # So padding with 255 works for positive integers.
        # To be safe with negative numbers (though test cases are positive), 
        # let's use 128 as padding or similar.
        
        PAD_VAL = 255
        dut_arr = py_arr + [PAD_VAL] * (8 - len(py_arr))
        
        # Check logic consistency in Python first
        expected_result = check_sorted_logic(dut_arr)
        
        # Set inputs
        # Access pattern: dut.arr[i].value
        for j in range(8):
            dut.arr[j].value = dut_arr[j]
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read output
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
        
        actual = int(dut.result.value)
        
        # Compare
        # Note: The test cases in the prompt might have specific expectations.
        # For example, [3,4,5,1,2] is True. Our padded logic yields True.
        # [4,3,1,2] is False. Padded logic yields False.
        
        if actual != int(expected):
            # Debug info
            dut._log.info(f"Input: {dut_arr}")
            dut._log.info(f"Expected: {expected}, Got: {actual}")
            raise TestFailure(f"Test {i} failed: Expected {expected}, got {actual}")
        else:
            passed += 1
            dut._log.info(f"Test {i} passed: Input {py_arr} -> Result {actual}")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
