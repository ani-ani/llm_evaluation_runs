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
async def test_sum_to_n(dut):
    """Test sum_to_n module with multiple test cases."""
    
    # Test cases: (n, expected_result)
    test_cases = [
        (1, 1),
        (5, 15),
        (6, 21),
        (10, 55),
        (11, 66),
        (30, 465),
        (100, 5050),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (n_val, expected) in enumerate(test_cases):
        # Set input
        dut.n.value = n_val
        
        # Wait for combinational logic to propagate
        await Timer(100, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Output has X/Z values")
        
        # Read result
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            dut._log.info(f"Test {i+1} PASSED: sum_to_n({n_val}) = {result}")
            passed += 1
        else:
            raise TestFailure(f"Test {i+1} FAILED: sum_to_n({n_val}) = {result}, expected {expected}")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    assert passed == total
