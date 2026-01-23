import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import math

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_opponent_location(dut):
    """Test opponent_location module with various l values"""
    
    # Test cases: (l, expected_float)
    test_cases = [
        (9, 9.585073),      # Sample 1
        (9, 9.585073),      # Sample 2
        (1, 0.617099663),   # Additional
        (2, 0.801732),      # Additional
        (1000, 117099.663999), # Edge case
    ]
    
    # Compute exact expected values using Python math
    test_cases_exact = []
    for l_val, _ in test_cases:
        expected = (l_val*l_val)/(math.pi*math.e) + 1.0/(l_val+1)
        test_cases_exact.append((l_val, expected))
    
    passed = 0
    failed = 0
    
    for i, (l_val, expected_float) in enumerate(test_cases_exact):
        dut.l.value = l_val
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.result_fixed.value):
            raise TestFailure(f"Test {i}: result_fixed undefined (X/Z)")
        
        result_fixed = int(dut.result_fixed.value)
        result_float = result_fixed / (2.0**32)  # Convert Q32.32 to float
        
        # Tolerance check (2^-16 for Q32.32 error margin)
        tolerance = 1e-6
        if abs(result_float - expected_float) > tolerance:
            dut._log.error(f"Test {i} (l={l_val}): expected {expected_float:.6f}, got {result_float:.6f}")
            failed += 1
        else:
            dut._log.info(f"Test {i} (l={l_val}): PASS (got {result_float:.6f})")
            passed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")