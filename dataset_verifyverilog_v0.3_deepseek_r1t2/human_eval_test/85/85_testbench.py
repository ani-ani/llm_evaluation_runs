import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper function to check for defined values
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_array_sum_even_odd(dut):
    """Test the array sum even odd module"""

    # Test cases format: (arr_values, len, expected_sum)
    test_cases = [
        # From problem description
        ([4, 88, 0, 0, 0, 0, 0, 0], 2, 88),
        # [4, 5, 6, 7, 2, 122] -> indices 0,1,2,3,4,5
        # Odd indices: 1(5), 3(7), 5(122)
        # Even values at odd indices: 122
        ([4, 5, 6, 7, 2, 122, 0, 0], 6, 122),
        # [4, 0, 6, 7] -> indices 0,1,2,3
        # Odd indices: 1(0), 3(7)
        # Even values at odd indices: 0
        ([4, 0, 6, 7, 0, 0, 0, 0], 4, 0),
        # [4, 4, 6, 8] -> indices 0,1,2,3
        # Odd indices: 1(4), 3(8)
        # Even values at odd indices: 4 + 8 = 12
        ([4, 4, 6, 8, 0, 0, 0, 0], 4, 12),
        # Edge case: empty length
        ([0, 0, 0, 0, 0, 0, 0, 0], 0, 0),
        # Edge case: only odd index elements, mix of even/odd
        ([0, 15, 0, 16, 0, 17, 0, 18], 8, 16 + 18),
    ]

    for i, (arr_vals, length, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {i}: arr={arr_vals}, len={length}")
        
        # Set array inputs
        # Rule 11: Assign elements individually for 2D array
        for j in range(8):
            dut.arr[j].value = arr_vals[j]
        
        # Set length
        dut.len.value = length
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check result validity
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
        
        # Read result
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i}: Expected {expected}, got {result}")
        
        dut._log.info(f"Test {i} passed: result={result}")

    dut._log.info(f"All {len(test_cases)} tests passed [OK]")
