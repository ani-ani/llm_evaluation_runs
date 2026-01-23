import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def sum_series_reference(n):
    """Reference Python implementation"""
    if n < 1:
        return 0
    return n + sum_series_reference(n - 2)

@cocotb.test()
async def test_sum_series(dut):
    """Test sum_series module with multiple test cases"""
    
    # Test cases from problem specification
    test_cases = [
        (6, 12),
        (10, 30),
        (9, 25),
        # Additional edge cases
        (0, 0),
        (1, 1),
        (2, 2),
        (3, 4),  # 3 + 1 = 4
        (4, 6),  # 4 + 2 = 6
        (5, 9),  # 5 + 3 + 1 = 9
        (7, 16), # 7 + 5 + 3 + 1 = 16
        (8, 20), # 8 + 6 + 4 + 2 = 20
        (15, 64), # 15 + 13 + 11 + 9 + 7 + 5 + 3 + 1 = 64
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_input, expected in test_cases:
        # Set input
        dut.n.value = n_input
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            passed += 1
            print(f"Test n={n_input}: PASS (result={result})")
        else:
            print(f"Test n={n_input}: FAIL (expected={expected}, got={result})")
            raise TestFailure(f"For n={n_input}, expected {expected} but got {result}")
    
    print(f"
Summary: {passed}/{total} tests passed")
