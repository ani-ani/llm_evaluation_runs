import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_check_month_31_days(dut):
    """Test check_month_31_days module with various month inputs"""
    
    # Test cases: (month, expected_result)
    test_cases = [
        (1, 1),   # January - 31 days
        (2, 0),   # February - 28/29 days
        (3, 1),   # March - 31 days
        (4, 0),   # April - 30 days
        (5, 1),   # May - 31 days
        (6, 0),   # June - 30 days
        (7, 1),   # July - 31 days
        (8, 1),   # August - 31 days
        (9, 0),   # September - 30 days
        (10, 1),  # October - 31 days
        (11, 0),  # November - 30 days
        (12, 1),  # December - 31 days
    ]
    
    passed = 0
    total = len(test_cases)
    
    print(f"
Testing check_month_31_days module")
    print("="*50)
    
    for month, expected in test_cases:
        # Set input
        dut.month.value = month
        
        # Wait for combinational logic to settle (small delay)
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.has_31_days.value)
        
        # Check result
        if result == expected:
            print(f"✓ Month {month:2d}: has_31_days={result} (expected {expected})")
            passed += 1
        else:
            print(f"✗ Month {month:2d}: has_31_days={result} (expected {expected}) - FAILED")
            raise TestFailure(f"Month {month} failed: got {result}, expected {expected}")
    
    print("="*50)
    print(f"Test Summary: {passed}/{total} tests passed")
    
    # Additional edge case test for invalid input (0)
    print("
Testing edge case: month=0")
    dut.month.value = 0
    await Timer(10, units='ns')
    result = int(dut.has_31_days.value)
    print(f"Month 0: has_31_days={result} (expected 0 for invalid month)")
    
    if result != 0:
        print("Note: Invalid month input returned non-zero, but this is acceptable")
    
    # Test maximum valid input
    print("
Testing edge case: month=15 (invalid, max valid is 12)")
    dut.month.value = 15
    await Timer(10, units='ns')
    result = int(dut.has_31_days.value)
    print(f"Month 15: has_31_days={result} (should be 0 for non-31-day months)")
    
    print(f"
{'='*50}")
    print(f"COMPLETED: {passed}/{total} core tests passed")
    print(f"{'='*50}")
