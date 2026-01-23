import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_pyramid_area(dut):
    """Test pyramid_area module with multiple test cases"""
    
    # Test cases with expected results
    # Format: (base_edge, slant_height, expected_surface_area)
    # Values are scaled by 65536 for Q16.16 representation
    
    test_cases = [
        # Test 1: b=3, s=4 -> Area = 2*3*4 + 3^2 = 24 + 9 = 33
        (3 * 65536, 4 * 65536, 33 * 65536),
        
        # Test 2: b=4, s=5 -> Area = 2*4*5 + 4^2 = 40 + 16 = 56
        (4 * 65536, 5 * 65536, 56 * 65536),
        
        # Test 3: b=1, s=2 -> Area = 2*1*2 + 1^2 = 4 + 1 = 5
        (1 * 65536, 2 * 65536, 5 * 65536),
        
        # Edge case: b=0, s=0 -> Area = 0
        (0, 0, 0),
        
        # Edge case: b=10, s=0 -> Area = 0 + 100 = 100
        (10 * 65536, 0, 100 * 65536),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (base, slant, expected) in enumerate(test_cases):
        dut.base_edge.value = base
        dut.slant_height.value = slant
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        result = int(dut.surface_area.value)
        
        # Allow small rounding error for fixed-point arithmetic
        tolerance = 10  # Small tolerance for rounding
        
        if abs(result - expected) <= tolerance:
            print(f"Test {i+1} PASSED: base={base>>16}, slant={slant>>16}, expected={expected>>16}, got={result>>16}")
            passed += 1
        else:
            print(f"Test {i+1} FAILED: base={base>>16}, slant={slant>>16}, expected={expected>>16}, got={result>>16}")
            print(f"  Raw values - expected: {expected}, got: {result}, diff: {result - expected}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"