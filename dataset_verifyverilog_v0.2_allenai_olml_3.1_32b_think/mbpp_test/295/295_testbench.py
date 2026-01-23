import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def calculate_sum_div(number):
    """Calculate sum of divisors (excluding number itself)"""
    if number <= 1:
        return 0
    total = 0
    for i in range(1, number):
        if number % i == 0:
            total += i
    return total

@cocotb.test()
async def test_sum_divisors(dut):
    """Test sum_divisors module with various test cases"""
    
    # Test cases: (input_number, expected_sum)
    test_cases = [
        (0, 0),      # Edge case: zero
        (1, 0),      # Edge case: one
        (7, 1),      # Prime number
        (8, 7),      # 1+2+4 = 7
        (12, 16),    # 1+2+3+4+6 = 16
        (255, 0),    # Edge case: max value (divisible by many, but we exclude itself)
        (2, 1),      # Smallest prime
        (4, 3),      # 1+2 = 3
        (10, 8),     # 1+2+5 = 8
        (15, 9),     # 1+3+5 = 9
        (6, 6),      # 1+2+3 = 6
        (9, 4),      # 1+3 = 4
        (100, 0),    # Will be truncated to 8-bit, 100 fits, actual sum=1+2+4+5+10+20+25+50=117
        (255, 0),    # 255 is 0xFF, max 8-bit
    ]
    
    passed = 0
    total = len(test_cases)
    
    for number, expected in test_cases:
        # Drive input
        dut.number.value = number
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.sum_result.value)
        
        # Calculate actual expected for this number
        actual_expected = calculate_sum_div(number)
        
        # For numbers > 255, they get truncated, so recalculate
        if number > 255:
            number = number & 0xFF
            actual_expected = calculate_sum_div(number)
        
        if result != actual_expected:
            raise TestFailure(f"Test failed for input {number}: expected {actual_expected}, got {result}")
        else:
            passed += 1
            dut._log.info(f"Test passed: sum_div({number}) = {result}")
    
    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
