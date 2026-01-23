import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_nonagonal_number(dut):
    """Test nonagonal number calculation for multiple values"""
    
    # Test cases: (n, expected_result)
    test_cases = [
        (10, 325),  # nonagonal(10) = 325
        (15, 750),  # nonagonal(15) = 750
        (18, 1089), # nonagonal(18) = 1089
        (1, 1),     # Edge case: first nonagonal number
        (5, 110),   # Additional test: nonagonal(5) = 110
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases for nonagonal number calculation")
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        result = int(dut.result.value)
        
        dut._log.info(f"n={n}: expected={expected}, got={result}")
        
        if result == expected:
            passed += 1
        else:
            raise TestFailure(f"Test failed for n={n}: expected {expected}, got {result}")
    
    dut._log.info(f"
=== Test Summary: {passed}/{total} tests passed ===")
    
    # Final assertion to ensure all tests passed
    assert passed == total, f"Only {passed} out of {total} tests passed"
