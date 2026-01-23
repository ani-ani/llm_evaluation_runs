import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import math

def float_to_q16_16(value):
    """Convert Python float to Q16.16 fixed-point format"""
    return int(value * 65536) & 0xFFFFFFFF

def q16_16_to_float(value):
    """Convert Q16.16 fixed-point to Python float"""
    # Handle signed values
    if value & 0x80000000:
        return (value - 0x100000000) / 65536.0
    return value / 65536.0

@cocotb.test()
async def test_truncate_number(dut):
    """Test truncate_number module with multiple test cases"""
    
    test_cases = [
        (3.5, 0.5),
        (1.33, 0.33),
        (123.456, 0.456),
        (1.0, 0.0),      # Edge case: whole number
        (0.125, 0.125),  # Edge case: fractional only
        (7.999, 0.999),  # Edge case: close to next integer
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_float, expected_float in test_cases:
        # Convert to Q16.16
        input_fixed = float_to_q16_16(input_float)
        expected_fixed = float_to_q16_16(expected_float)
        
        # Apply input
        dut.number_in.value = input_fixed
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read output
        result = dut.decimal_out.value.integer
        
        # Convert back to float for comparison
        result_float = q16_16_to_float(result)
        
        # Calculate error
        error = abs(result_float - expected_float)
        tolerance = 0.001  # Q16.16 precision is about 0.000015, so 0.001 is safe
        
        print(f"Input: {input_float} (0x{input_fixed:08X}) -> Output: {result_float:.6f} (0x{result:08X}), Expected: {expected_float:.6f}, Error: {error:.6f}")
        
        if error < tolerance:
            passed += 1
        else:
            raise TestFailure(f"Test failed for input {input_float}: got {result_float}, expected {expected_float}, error {error}")
    
    print(f"
{passed}/{total} tests passed")
    
    if passed == total:
        print("All tests PASSED!")
    else:
        raise TestFailure(f"Only {passed}/{total} tests passed")
