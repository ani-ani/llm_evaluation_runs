import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_right_angle_triangle(dut):
    """Test right_angle_triangle module with various test cases"""
    
    # Test cases adapted from Python problem
    # Format: (a, b, c, expected_result)
    test_cases = [
        (3, 4, 5, True),      # Classic 3-4-5 right triangle
        (1, 2, 3, False),     # Not a triangle (violates triangle inequality) and not right
        (10, 6, 8, True),     # 6-8-10 (scaled 3-4-5)
        (2, 2, 2, False),     # Equilateral, not right
        (7, 24, 25, True),    # Pythagorean triple
        (10, 5, 7, False),    # Not right
        (5, 12, 13, True),    # Pythagorean triple
        (15, 8, 17, True),    # Pythagorean triple
        (48, 55, 73, True),   # Pythagorean triple
        (1, 1, 1, False),     # Equilateral
        (2, 2, 10, False),    # Not a triangle
        (0, 0, 0, False),     # Edge case: all zeros
        (1, 0, 1, False),     # Degenerate triangle
        (0, 3, 5, False),     # Zero side
        (9, 12, 15, True),    # Another 3-4-5 multiple
        (8, 15, 17, True),    # Pythagorean triple
    ]
    
    passed = 0
    total = len(test_cases)
    
    print(f"
Running {total} test cases...")
    print("-" * 60)
    
    for i, (a, b, c, expected) in enumerate(test_cases):
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.result.value)
        expected_int = 1 if expected else 0
        
        # Check result
        test_name = f"Test {i+1}: a={a}, b={b}, c={c}"
        if result == expected_int:
            print(f"✓ PASS: {test_name} => {result} (expected {expected_int})")
            passed += 1
        else:
            print(f"✗ FAIL: {test_name} => {result} (expected {expected_int})")
    
    print("-" * 60)
    print(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
