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

async def wait_for_valid_output(dut, timeout_ns=1000):
    """Poll for valid combinational output."""
    elapsed = 0
    while elapsed < timeout_ns:
        await Timer(10, units='ns')
        elapsed += 10
        all_valid = True
        for i in range(8):
            if not is_value_defined(dut.result[i].value):
                all_valid = False
                break
        if all_valid:
            return True
    raise TestFailure(f"Timeout: output not valid after {timeout_ns}ns")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_compare_arrays(dut):
    """Test the compare_arrays module with multiple test cases."""
    
    # Define test cases as tuples of (score_array, guess_array, expected_result_array)
    # Values are in decimal (signed)
    test_cases = [
        # Test case 1: From the problem description
        ([1, 2, 3, 4, 5, 1], [1, 2, 3, 4, 2, -2], [0, 0, 0, 0, 3, 3]),
        
        # Test case 2: All zeros
        ([0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0]),
        
        # Test case 3: All different, negative guesses
        ([1, 2, 3, 0, 0, 0], [-1, -2, -3, 0, 0, 0], [2, 4, 6, 0, 0, 0]),
        
        # Test case 4: Mixed differences
        ([1, 2, 3, 5, 0, 0, 0, 0], [-1, 2, 3, 4, 0, 0, 0, 0], [2, 0, 0, 1, 0, 0, 0, 0]),
        
        # Test case 5: Maximum values
        ([127, -128, 0, 0, 0, 0, 0, 0], [127, -128, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]),
        
        # Test case 6: Large differences
        ([127, -128, 100, 50, 0, 0, 0, 0], [-128, 127, 50, 100, 0, 0, 0, 0], [255, 255, 50, 50, 0, 0, 0, 0]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (score_vals, guess_vals, expected_vals) in enumerate(test_cases):
        dut._log.info(f"Running test case {idx + 1}/{total}")
        
        # Pad arrays to length 8 if needed
        while len(score_vals) < 8:
            score_vals.append(0)
        while len(guess_vals) < 8:
            guess_vals.append(0)
        while len(expected_vals) < 8:
            expected_vals.append(0)
        
        # Assign inputs (convert signed to unsigned representation)
        for i in range(8):
            dut.score[i].value = from_signed(score_vals[i], 8)
            dut.guess[i].value = from_signed(guess_vals[i], 8)
        
        # Wait for combinational logic to propagate
        await wait_for_valid_output(dut, timeout_ns=1000)
        
        # Verify outputs
        test_passed = True
        for i in range(8):
            if not is_value_defined(dut.result[i].value):
                raise TestFailure(f"Test {idx + 1}, index {i}: Result has X/Z values")
            
            actual = int(dut.result[i].value)
            expected = expected_vals[i] & 0xFF  # Ensure 8-bit unsigned
            
            if actual != expected:
                dut._log.error(f"Test {idx + 1}, index {i}: Expected {expected}, got {actual}")
                dut._log.error(f"  Score: {score_vals[i]}, Guess: {guess_vals[i]}")
                test_passed = False
        
        if test_passed:
            passed += 1
            dut._log.info(f"Test case {idx + 1} [OK]")
        else:
            raise TestFailure(f"Test case {idx + 1} failed")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")