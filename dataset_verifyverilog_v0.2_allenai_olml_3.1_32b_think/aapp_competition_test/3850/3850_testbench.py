import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

# Helper function to calculate expected result
def calculate_expected(p, people, keys):
    n = 2
    k = 4
    min_max_time = float('inf')
    
    # Check all valid windows of size n in sorted keys
    for i in range(k - n + 1):
        max_time = 0
        for j in range(n):
            # Distance person to key + key to office
            dist = abs(people[j] - keys[i+j]) + abs(keys[i+j] - p)
            if dist > max_time:
                max_time = dist
        if max_time < min_max_time:
            min_max_time = max_time
    
    return min_max_time

@cocotb.test()
async def test_key_assignment(dut):
    """Test the key assignment module with various inputs"""
    
    # Test cases: (p, [people0, people1], [key0, key1, key2, key3])
    test_cases = [
        (50, [20, 100], [10, 40, 60, 80]),    # Example 1 adapted (sorted)
        (10, [11], [7, 15]),                   # Example 2 (padded for n=2)
        (15, [4, 10], [21, 22, 23, 29]),       # Random small test
        (100, [1, 5], [2, 3, 100, 101]),       # Crossing paths
        (5, [1, 2, 3], [5, 6, 7, 8]),          # Edge case (note: people array must be size 2)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for p, people_list, keys_list in test_cases:
        # Ensure inputs match module interface (n=2, k=4)
        # Pad if necessary or truncate
        people_input = people_list[:2]
        if len(people_input) < 2:
            people_input.extend([0] * (2 - len(people_input)))
        
        keys_input = keys_list[:4]
        if len(keys_input) < 4:
            keys_input.extend([0] * (4 - len(keys_input)))
            
        # Sort inputs (algorithm assumes sorted)
        people_input.sort()
        keys_input.sort()
        
        # Calculate expected value
        expected = calculate_expected(p, people_input, keys_input)
        
        # Apply inputs to DUT
        dut.p.value = p
        dut.people0.value = people_input[0]
        dut.people1.value = people_input[1]
        dut.key0.value = keys_input[0]
        dut.key1.value = keys_input[1]
        dut.key2.value = keys_input[2]
        dut.key3.value = keys_input[3]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        actual = int(dut.result.value)
        
        # Verify
        if actual == expected:
            passed += 1
            print(f"PASS: P={p}, People={people_input}, Keys={keys_input} -> Result={actual} (Expected={expected})")
        else:
            print(f"FAIL: P={p}, People={people_input}, Keys={keys_input} -> Result={actual} (Expected={expected})")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Some tests failed: {passed}/{total}"
