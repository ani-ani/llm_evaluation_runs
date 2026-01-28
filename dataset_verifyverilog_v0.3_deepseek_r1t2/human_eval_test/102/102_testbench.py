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
async def test_choose_num(dut):
    """Test the choose_num module with various ranges."""
    
    # Helper function to set inputs and wait for combinational propagation
    async def compute(x_val, y_val):
        # Set inputs
        dut.x.value = x_val
        dut.y.value = y_val
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Output undefined for x={x_val}, y={y_val}")
        
        return int(dut.result.value)
    
    # Test cases adapted from Python problem
    # Format: (x, y, expected_result)
    test_cases = [
        (12, 15, 14),      # 14 is largest even in [12, 15]
        (13, 12, 0xFFFF),  # Invalid range (x > y)
        (33, 12354, 12354), # 12354 is even and >= 33
        (5234, 5233, 0xFFFF), # Invalid range
        (6, 29, 28),       # 28 is largest even in [6, 29]
        (27, 10, 0xFFFF),  # Invalid range
        (7, 7, 0xFFFF),    # 7 is odd, range is single element
        (546, 546, 546),   # 546 is even, range is single element
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (x, y, expected) in enumerate(test_cases):
        result = await compute(x, y)
        
        if result == expected:
            dut._log.info(f"Test {i+1} PASSED: choose_num({x}, {y}) = {result}")
            passed += 1
        else:
            # Handle -1 representation
            exp_str = "-1" if expected == 0xFFFF else str(expected)
            res_str = "-1" if result == 0xFFFF else str(result)
            raise TestFailure(f"Test {i+1} FAILED: choose_num({x}, {y}) returned {res_str}, expected {exp_str}")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed} of {total} tests passed")
