import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_centered_hexagonal(dut):
    """Test centered hexagonal number calculation"""
    
    # Test cases: (n, expected_result)
    test_cases = [
        (1, 1),      # Edge case
        (2, 7),      # From test 2
        (9, 217),    # From test 3
        (10, 271),   # From test 1
        (15, 631),   # Additional test
        (20, 1141),  # Additional test
        (255, 194527) # Maximum 8-bit value
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = dut.result.value.integer
        
        # Verify
        if result == expected:
            passed += 1
            print(f"PASS: n={n}, result={result}, expected={expected}")
        else:
            print(f"FAIL: n={n}, got {result}, expected {expected}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
