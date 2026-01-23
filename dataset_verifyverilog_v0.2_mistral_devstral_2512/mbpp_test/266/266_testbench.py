import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_lateral_surface_area(dut):
    """Test lateral surface area calculation for various cube side lengths"""
    
    # Test cases: (side_length, expected_lsa)
    test_cases = [
        (5, 100),   # 4 * 5 * 5 = 100
        (9, 324),   # 4 * 9 * 9 = 324
        (10, 400),  # 4 * 10 * 10 = 400
    ]
    
    passed = 0
    total = len(test_cases)
    
    print("
=== Testing Lateral Surface Area Module ===")
    
    for side, expected in test_cases:
        # Set input
        dut.side_length.value = side
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.lsa.value)
        
        # Verify
        if result == expected:
            print(f"✓ Test passed: side_length={side}, lsa={result} (expected {expected})")
            passed += 1
        else:
            print(f"✗ Test failed: side_length={side}, lsa={result} (expected {expected})")
    
    # Additional edge case tests
    print("
=== Additional Edge Cases ===")
    edge_cases = [
        (0, 0),     # Zero side
        (1, 4),     # Minimum non-zero
        (2, 16),    # Power of 2
    ]
    
    for side, expected in edge_cases:
        dut.side_length.value = side
        await Timer(10, units='ns')
        result = int(dut.lsa.value)
        
        if result == expected:
            print(f"✓ Edge case passed: side_length={side}, lsa={result} (expected {expected})")
            passed += 1
        else:
            print(f"✗ Edge case failed: side_length={side}, lsa={result} (expected {expected})")
        total += 1
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
