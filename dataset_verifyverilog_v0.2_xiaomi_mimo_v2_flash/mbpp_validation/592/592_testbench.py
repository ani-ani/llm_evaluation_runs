import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def binomial_coeff_reference(n):
    """Reference Python implementation for C(2n, n-1)"""
    if n == 0:
        return 0
    k = n - 1
    N = 2 * n
    # Compute C(N, k) using direct formula or iterative method
    if k > N - k:
        k = N - k
    if k == 0:
        return 1
    result = 1
    for i in range(k):
        result = result * (N - i) // (i + 1)
    return result

@cocotb.test()
async def test_binomial_sum(dut):
    """Test binomial coefficient computation for various n values"""
    
    # Test cases: (n, expected_result)
    test_cases = [
        (1, 1),   # C(2,0) = 1
        (2, 2),   # C(4,1) = 4, but wait... C(4,1)=4, let me recalculate
        (3, 15),  # C(6,2) = 15
        (4, 56),  # C(8,3) = 56
    ]
    
    # Correction: Let's verify test cases
    # n=1: C(2,0) = 1 ✓
    # n=2: C(4,1) = 4 (given test case says sum_Of_product(2) is not provided, but let's calculate)
    # Wait, original tests only have n=1,3,4. Let me recalculate n=2
    # n=2: C(4,1) = 4! / (1! * 3!) = 24 / 6 = 4
    # But I'll use only the provided tests
    
    actual_tests = [
        (1, 1),
        (3, 15),
        (4, 56),
        (2, 4),  # Additional test
        (5, 252), # C(10,4) = 252
    ]
    
    passed = 0
    total = len(actual_tests)
    
    for n, expected in actual_tests:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.result.value)
        
        if result == expected:
            passed += 1
            dut._log.info(f"n={n}: Got {result}, Expected {expected} ✓")
        else:
            dut._log.error(f"n={n}: Got {result}, Expected {expected} ✗")
            raise TestFailure(f"Mismatch for n={n}")
    
    dut._log.info(f"
{passed}/{total} tests passed")
