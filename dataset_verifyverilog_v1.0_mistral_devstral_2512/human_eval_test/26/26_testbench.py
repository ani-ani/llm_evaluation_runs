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

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_remove_duplicates(dut):
    """Test remove_duplicates module with various test cases"""
    
    # Helper function to set input array
    def set_input_array(values):
        """Set the input array elements. Values should be a list of up to 8 integers."""
        # Initialize all 8 positions
        for i in range(8):
            if i < len(values):
                dut.numbers[i].value = values[i]
            else:
                dut.numbers[i].value = 0  # Don't care for unused positions
        # Set length
        dut.length.value = len(values)
    
    # Helper function to read output array
    def read_output_array():
        """Read the output array and return as list."""
        result = []
        if not is_value_defined(dut.result_length.value):
            raise TestFailure("result_length is undefined")
        
        result_length = int(dut.result_length.value)
        
        # Read result array
        for i in range(result_length):
            if not is_value_defined(dut.result[i].value):
                raise TestFailure(f"result[{i}] is undefined")
            result.append(int(dut.result[i].value))
        
        return result, result_length
    
    # Wait for combinational logic to propagate
    async def wait_for_output():
        await Timer(100, units='ns')
    
    test_cases = [
        ("empty", [], []),
        ("no_dups", [1, 2, 3, 4], [1, 2, 3, 4]),
        ("one_dup", [1, 2, 3, 2, 4], [1, 3, 4]),
        ("multi_dups", [1, 2, 3, 2, 4, 3, 5], [1, 4, 5]),
        ("all_same", [5, 5, 5, 5], []),
        ("single", [42], [42]),
        ("dups_at_ends", [1, 2, 1, 3, 2], [3]),
        ("adjacent_dups", [1, 1, 2, 2, 3, 3], []),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for name, input_vals, expected in test_cases:
        dut._log.info(f"Test case: {name}")
        dut._log.info(f"Input: {input_vals}")
        dut._log.info(f"Expected: {expected}")
        
        # Set inputs
        set_input_array(input_vals)
        
        # Wait for propagation
        await wait_for_output()
        
        # Read outputs
        result, result_length = read_output_array()
        
        dut._log.info(f"Got result_length: {result_length}")
        dut._log.info(f"Got result: {result}")
        
        # Verify
        if result_length != len(expected):
            raise TestFailure(f"{name}: Expected length {len(expected)}, got {result_length}")
        
        if result != expected:
            raise TestFailure(f"{name}: Expected {expected}, got {result}")
        
        dut._log.info(f"Test {name} passed")
        passed += 1
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_edge_cases(dut):
    """Test edge cases with values near 8-bit boundaries"""
    
    async def test_case(name, input_vals, expected):
        dut._log.info(f"Edge case: {name}")
        
        for i in range(8):
            if i < len(input_vals):
                dut.numbers[i].value = input_vals[i]
            else:
                dut.numbers[i].value = 0
        dut.length.value = len(input_vals)
        
        await Timer(100, units='ns')
        
        result_length = int(dut.result_length.value)
        result = []
        for i in range(result_length):
            result.append(int(dut.result[i].value))
        
        if result != expected:
            raise TestFailure(f"{name}: Expected {expected}, got {result}")
        
        return True
    
    # Test with max 8-bit values
    await test_case("max_values", [255, 254, 253, 255, 254], [253])
    
    # Test with zeros
    await test_case("with_zeros", [0, 1, 0, 2, 0], [1, 2])
    
    # Test full array, no duplicates
    await test_case("full_no_dups", [1, 2, 3, 4, 5, 6, 7, 8], [1, 2, 3, 4, 5, 6, 7, 8])
    
    # Test full array with duplicates
    await test_case("full_with_dups", [1, 2, 1, 2, 3, 3, 4, 4], [])
    
    dut._log.info("All edge cases passed [OK]")
