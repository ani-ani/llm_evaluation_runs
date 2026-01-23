import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_eulerian_number(dut):
    """Test Eulerian number computation"""
    
    # Test cases from the problem
    test_cases = [
        (3, 1, 4),   # a(3, 1) = 4
        (4, 1, 11),  # a(4, 1) = 11
        (5, 3, 26),  # a(5, 3) = 26
        # Additional test cases
        (0, 0, 0),   # Edge case: n=0
        (1, 0, 1),   # Base case: m=0
        (2, 1, 1),   # a(2, 1) = 1
        (4, 2, 11),  # a(4, 2) = 11
        (5, 2, 66),  # a(5, 2) = 66
        (6, 3, 302), # a(6, 3) = 302
        (8, 4, 1764), # Maximum value for our constraints
        (3, 3, 0),   # Invalid: m >= n
        (5, 6, 0),   # Invalid: m >= n
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, m, expected in test_cases:
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.result.value)
        
        # Check result
        if result == expected:
            passed += 1
            print(f"PASS: a({n}, {m}) = {result} (expected {expected})")
        else:
            print(f"FAIL: a({n}, {m}) = {result} (expected {expected})")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
}