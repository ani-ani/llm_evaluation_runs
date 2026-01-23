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

def to_signed(val, bits):
    """Convert unsigned to signed representation."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed to unsigned for assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_poly_derivative(dut):
    """Test polynomial derivative computation."""
    
    # Wait for combinational logic to settle
    await Timer(50, units='ns')
    
    test_cases = [
        # (description, input_coeffs, input_len, expected_coeffs, expected_len)
        (
            "Test 1: [3,1,2,4,5] -> [1,4,12,20]",
            [3, 1, 2, 4, 5],
            5,
            [1, 4, 12, 20],
            4
        ),
        (
            "Test 2: [1,2,3] -> [2,6]",
            [1, 2, 3],
            3,
            [2, 6],
            2
        ),
        (
            "Test 3: [3,2,1] -> [2,2]",
            [3, 2, 1],
            3,
            [2, 2],
            2
        ),
        (
            "Test 4: [3,2,1,0,4] -> [2,2,0,16]",
            [3, 2, 1, 0, 4],
            5,
            [2, 2, 0, 16],
            4
        ),
        (
            "Test 5: [1] -> []",
            [1],
            1,
            [],
            0
        ),
        (
            "Test 6: [5, 10] -> [10]",
            [5, 10],
            2,
            [10],
            1
        ),
        (
            "Test 7: Edge case with negative coefficients",
            [-10, -20, -30],
            3,
            [-20, -60],
            2
        )
    ]
    
    tests_passed = 0
    tests_total = len(test_cases)
    
    for test_i, (desc, input_coeffs, input_len, expected_coeffs, expected_len) in enumerate(test_cases):
        dut._log.info(f"Running {desc}")
        
        # Set up inputs
        # For 2D array access, we use dut.xs[i].value pattern
        for i in range(8):
            if i < input_len:
                val = input_coeffs[i]
                # Convert to unsigned for assignment
                val_unsigned = from_signed(val, 16)
                dut.xs[i].value = val_unsigned
            else:
                dut.xs[i].value = 0
        
        dut.len.value = input_len
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        
        # Check outputs are defined
        if not is_value_defined(dut.y_len.value):
            raise TestFailure(f"{desc}: y_len is undefined (X/Z)")
        
        actual_len = int(dut.y_len.value)
        
        if actual_len != expected_len:
            raise TestFailure(f"{desc}: y_len mismatch - expected {expected_len}, got {actual_len}")
        
        # Check each output coefficient
        for i in range(expected_len):
            if not is_value_defined(dut.ys[i].value):
                raise TestFailure(f"{desc}: ys[{i}] is undefined (X/Z)")
            
            actual_val_unsigned = int(dut.ys[i].value)
            actual_val = to_signed(actual_val_unsigned, 16)
            expected_val = expected_coeffs[i]
            
            if actual_val != expected_val:
                raise TestFailure(f"{desc}: ys[{i}] mismatch - expected {expected_val}, got {actual_val}")
        
        # For len=0 case, also verify that ys array doesn't have garbage
        if expected_len == 0:
            # All ys elements should be 0 or don't care, but y_len is what matters
            dut._log.info(f"{desc}: Correctly returned empty result (y_len=0)")
        
        tests_passed += 1
        dut._log.info(f"{desc}: PASSED")
    
    dut._log.info(f"\nSummary: {tests_passed}/{tests_total} tests passed")
    
    if tests_passed != tests_total:
        raise TestFailure(f"Only {tests_passed}/{tests_total} tests passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_edge_case_max_len(dut):
    """Test with maximum length 8."""
    await Timer(50, units='ns')
    
    # Input: [0,1,2,3,4,5,6,7] -> [1,4,12,24,40,60,84,112]
    # Derivative: i * xs[i] for i=1..7
    input_coeffs = [0, 1, 2, 3, 4, 5, 6, 7]
    expected = [1, 4, 12, 24, 40, 60, 84]  # 1*1, 2*2, 3*3, 4*4, 5*5, 6*6, 7*7
    
    for i in range(8):
        dut.xs[i].value = input_coeffs[i]
    
    dut.len.value = 8
    
    await Timer(100, units='ns')
    
    if not is_value_defined(dut.y_len.value):
        raise TestFailure("y_len undefined in max_len test")
    
    actual_len = int(dut.y_len.value)
    if actual_len != 7:
        raise TestFailure(f"Max len test: expected y_len=7, got {actual_len}")
    
    for i in range(7):
        if not is_value_defined(dut.ys[i].value):
            raise TestFailure(f"ys[{i}] undefined in max_len test")
        actual = to_signed(int(dut.ys[i].value), 16)
        if actual != expected[i]:
            raise TestFailure(f"Max len test: ys[{i}] expected {expected[i]}, got {actual}")
    
    dut._log.info("Edge case max_len: PASSED")
