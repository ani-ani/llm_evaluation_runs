import cocotb
from cocotb.triggers import Timer
import random

# Helper function to check primality in Python
def is_prime(n):
    if n <= 1:
        return False
    for i in range(2, int(n**0.5) + 1):
        if n % i == 0:
            return False
    return True

@cocotb.test()
async def test_prime_length(dut):
    """Test prime_length module with various string lengths"""
    
    # Test cases: (length, expected_result)
    test_cases = [
        (0, False),   # Empty string
        (1, False),   # Single char
        (2, True),    # Prime
        (3, True),    # Prime
        (4, False),   # Composite
        (5, True),    # Prime
        (6, False),   # Composite
        (7, True),    # Prime
        (8, False),   # Composite
        (9, False),   # Composite
        (10, False),  # Composite
        (11, True),   # Prime
        (12, False),  # Composite
        (13, True),   # Prime
        (14, False),  # Composite
        (15, False),  # Composite
    ]
    
    passed = 0
    total = len(test_cases)
    
    for length, expected in test_cases:
        # Set input string length
        dut.string_length.value = length
        
        # Set a dummy string data (doesn't matter for length check, but need to drive it)
        # Let's just set it to 0 for simplicity
        dut.string_data.value = 0
        
        # Wait a small amount of time for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = dut.is_prime.value
        result_bool = bool(result)
        
        # Check
        assert result_bool == expected, f"Length {length}: Expected {expected}, got {result_bool}"
        
        if result_bool == expected:
            passed += 1
            print(f"PASS: Length {length} -> {result_bool}")
        else:
            print(f"FAIL: Length {length} -> {result_bool} (Expected {expected})")
            
    print(f"
Summary: {passed}/{total} tests passed")