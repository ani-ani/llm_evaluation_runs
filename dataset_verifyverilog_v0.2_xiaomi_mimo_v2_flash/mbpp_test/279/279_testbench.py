import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_decagonal(dut):
    """Test decagonal number calculation"""
    
    # Test cases from the problem
    test_cases = [
        (3, 27),
        (7, 175),
        (10, 370),
        # Additional edge cases
        (0, 0),      # First decagonal number
        (1, 1),      # Second decagonal number  
        (2, 10),     # Third decagonal number
        (20, 1540),  # Larger test case
        (255, 260100), # Max value test
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            passed += 1
            print(f"Test n={n}: PASS (got {result}, expected {expected})")
        else:
            print(f"Test n={n}: FAIL (got {result}, expected {expected})")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
