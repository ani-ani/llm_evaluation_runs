import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_compare_arrays(dut):
    """Test the compare_arrays module with various score and guess pairs"""
    
    # Test case data: (score, guess, expected_diff)
    test_cases = [
        # Basic cases from problem
        (1, 1, 0),
        (2, 2, 0),
        (3, 3, 0),
        (4, 4, 0),
        (5, 2, 3),
        (1, -2, 3),
        # More test cases
        (0, 4, 4),
        (5, 1, 4),
        (0, 1, 1),
        (0, 0, 0),
        (4, -2, 6),
        # Edge cases
        (-1, -1, 0),
        (-1, 1, 2),
        (1, -1, 2),
        (127, -128, 255),  # Max range
        (0, 0, 0),
        # Additional cases for coverage
        (10, 20, 10),
        (-5, -3, 2),
        (100, 50, 50),
    ]
    
    passed = 0
    failed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (score, guess, expected) in enumerate(test_cases):
        # Set inputs
        dut.scores_i.value = score & 0xFF  # 8-bit unsigned representation
        dut.guesses_i.value = guess & 0xFF  # 8-bit unsigned representation
        dut.index.value = i % 8  # Just select an index (not used in this design but kept for interface)
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        actual = dut.diff_o.value.integer
        
        # Check result
        if actual == expected:
            dut._log.info(f"Test {i+1}: score={score}, guess={guess} -> diff={actual} (expected {expected}) PASS")
            passed += 1
        else:
            dut._log.error(f"Test {i+1}: score={score}, guess={guess} -> diff={actual} (expected {expected}) FAIL")
            failed += 1
    
    dut._log.info(f"
=== Summary: {passed}/{total} tests passed ===")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {total} tests failed")

@cocotb.test()
async def test_compare_arrays_edge_cases(dut):
    """Test edge cases for the compare_arrays module"""
    
    # Edge cases to verify
    edge_cases = [
        (0, 0, 0),      # Zero vs zero
        (127, 127, 0),  # Max positive equal
        (-128, -128, 0), # Max negative equal
        (127, -128, 255), # Max range difference (127 - (-128) = 255)
        (-128, 127, 255), # Reverse max range
        (1, -1, 2),     # Small negative difference
        (-1, 1, 2),     # Negative to positive
        (50, 50, 0),    # Mid-range equal
    ]
    
    passed = 0
    failed = 0
    total = len(edge_cases)
    
    dut._log.info(f"Running {total} edge case tests...")
    
    for score, guess, expected in edge_cases:
        # Convert to 8-bit representation
        dut.scores_i.value = score & 0xFF
        dut.guesses_i.value = guess & 0xFF
        dut.index.value = 0
        
        await Timer(10, units='ns')
        
        actual = dut.diff_o.value.integer
        
        if actual == expected:
            dut._log.info(f"Edge: score={score}, guess={guess} -> diff={actual} PASS")
            passed += 1
        else:
            dut._log.error(f"Edge: score={score}, guess={guess} -> diff={actual} (expected {expected}) FAIL")
            failed += 1
    
    dut._log.info(f"
=== Edge Summary: {passed}/{total} tests passed ===")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {total} edge tests failed")
