import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_square_sum(dut):
    """Test square_sum module with various inputs"""
    
    # Test cases with expected results
    test_cases = [
        (0, 0),      # Sum of 0 odd numbers
        (1, 1),      # 1² = 1
        (2, 10),     # 1² + 3² = 1 + 9 = 10
        (3, 35),     # 1² + 3² + 5² = 1 + 9 + 25 = 35
        (4, 84),     # 1² + 3² + 5² + 7² = 1 + 9 + 25 + 49 = 84
        (5, 165),    # 1² + 3² + 5² + 7² + 9² = 165
        (10, 1430),  # Larger test case
        (20, 11320), # Even larger
        (63, 524159),# Maximum safe value
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Drive input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            print(f"✓ n={n}: result={result} (expected {expected})")
            passed += 1
        else:
            print(f"✗ n={n}: result={result} (expected {expected})")
            raise TestFailure(f"Test failed for n={n}: got {result}, expected {expected}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
