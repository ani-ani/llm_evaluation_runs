import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_divisor_parity(dut):
    """Test divisor parity detection for various inputs"""
    
    # Test cases: (n, expected_even_divisors)
    test_cases = [
        (10, True),      # 10: non-perfect square, even divisors
        (100, False),    # 100: perfect square, odd divisors
        (125, True),     # 125: non-perfect square, even divisors
        (0, True),       # Edge case: 0 (convention)
        (1, False),      # 1: perfect square
        (4, False),      # 4: perfect square (2*2)
        (15, True),      # 15: non-perfect square
        (16, False),     # 16: perfect square (4*4)
        (25, False),     # 25: perfect square (5*5)
        (26, True),      # 26: non-perfect square
        (65535, True),   # Max value: non-perfect square
        (256, False),    # 256: perfect square (16*16)
        (255, True),     # 255: non-perfect square
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected_even in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.even_divisors.value)
        expected = 1 if expected_even else 0
        
        if result == expected:
            passed += 1
        else:
            raise TestFailure(
                f"Test failed for n={n}: expected even_divisors={expected} ({'even' if expected else 'odd'}), "
                f"got {result} ({'even' if result else 'odd'})"
            )
    
    print(f"
Results: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
