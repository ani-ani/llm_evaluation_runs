import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import math

# Q16.16 Helpers
def float_to_fixed_16_16(f):
    return int(f * 65536)

def fixed_to_float_16_16(v):
    return v / 65536.0

# Precision tolerance
TOLERANCE = 0.01  # Allow 1/100 error due to fixed point precision

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_cone_lsa_calc(dut):
    """
    Test fixed-point cone lateral surface area calculation.
    """
    # Test cases: (r_int, h_int, expected_float)
    test_cases = [
        (5, 12, 204.20352248333654),
        (10, 15, 566.3586699569488),
        (19, 17, 1521.8090132193388)
    ]

    passed = 0
    failed = 0

    for i, (r_int, h_int, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test Case {i+1}: r={r_int}, h={h_int}")
        
        # Set inputs
        dut.r.value = r_int
        dut.h.value = h_int
        
        # Wait for combinational logic
        await Timer(50, units='ns')
        
        # Read output
        if not hasattr(dut, 'area'):
            cocotb.log.error("DUT has no 'area' output signal")
            failed += 1
            continue
            
        result_val = dut.area.value
        if not result_val.is_resolvable:
            raise TestFailure(f"Output 'area' is not resolved (X/Z) for r={r_int}, h={h_int}")
        
        result_int = int(result_val)
        result_float = fixed_to_float_16_16(result_int)
        
        cocotb.log.info(f"  Result (fixed): {result_int}, Result (float): {result_float:.6f}, Expected: {expected:.6f}")
        
        # Check error
        error = abs(result_float - expected)
        percent_error = (error / expected) * 100 if expected != 0 else float('inf')
        
        # Allow small absolute error or percentage based on magnitude
        if error > TOLERANCE and percent_error > 0.5: # 0.5% tolerance or 0.01 absolute
            cocotb.log.error(f"  FAIL: Error {error:.6f} ({percent_error:.2f}%) exceeds tolerance")
            failed += 1
        else:
            cocotb.log.info("  PASS")
            passed += 1

    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
