import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def int_to_digits(n):
    """Helper to calculate sum of digits in Python"""
    if n == 0:
        return 0
    total = 0
    while n > 0:
        total += n % 10
        n //= 10
    return total

@cocotb.test()
async def test_digit_sum(dut):
    """Test digit sum calculation for various inputs"""
    
    # Test cases from problem
    test_cases = [
        (345, 12),
        (12, 3),
        (97, 16),
        (0, 0),      # Edge case: zero
        (999, 27),   # Multiple digits
        (1000, 1),   # Contains zeros
        (65535, 30), # Maximum 16-bit value
    ]
    
    passed = 0
    total = len(test_cases)
    
    for num, expected in test_cases:
        dut.num.value = num
        await Timer(10, units='ns')  # Allow combinational logic to settle
        
        actual = dut.sum.value.integer
        
        if actual != expected:
            raise TestFailure(f"Test failed for input {num}: expected {expected}, got {actual}")
        
        print(f"Input: {num} → Sum: {actual} (expected {expected}) ✓")
        passed += 1
    
    print(f"
{passed}/{total} tests passed")
