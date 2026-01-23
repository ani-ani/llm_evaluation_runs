import cocotb
from cocotb.triggers import Timer
import random

def solve_python(n, s1, s2, t):
    """Original DP solution"""
    dp = {}
    dp[(0,0)] = True
    max_served = 0
    
    for i in range(n):
        new_dp = {}
        customer_time = t[i]
        any_valid = False
        
        for (t1, t2) in dp:
            # Assign to counter 1
            if t1 + customer_time <= s1:
                new_dp[(t1 + customer_time, t2)] = True
                any_valid = True
            # Assign to counter 2  
            if t2 + customer_time <= s2:
                new_dp[(t1, t2 + customer_time)] = True
                any_valid = True
        
        if not any_valid:
            break
            
        dp = new_dp
        max_served = i + 1
        
    return max_served

@cocotb.test()
async def test_license_scheduling(dut):
    """Test the license scheduling module with multiple test cases"""
    
    print("
=== License Scheduling Test ===")
    
    test_cases = [
        # (n, s1, s2, t_list, expected_result)
        (5, 20, 20, [7, 11, 9, 12, 2], 4),  # Original example 1
        (5, 100, 100, [101, 1, 1, 1, 1], 0),  # Original example 2
        (4, 15, 15, [5, 5, 5, 5], 4),  # All fit both counters
        (6, 10, 10, [3, 4, 5, 6, 7, 8], 2),  # Complex selection
        (3, 20, 5, [8, 9, 10], 2),  # Counter 2 fills up fast
        (2, 10, 10, [3, 4], 2),  # Simple case
        (8, 64, 64, [10]*8, 8),  # Maximum customers
        (0, 10, 10, [], 0),  # No customers
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (n, s1, s2, t_list, expected) in enumerate(test_cases):
        # Set inputs
        dut.n.value = n
        dut.s1.value = s1
        dut.s2.value = s2
        
        # Fill t array
        for j in range(8):
            if j < len(t_list):
                dut.t[j].value = t_list[j]
            else:
                dut.t[j].value = 0
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        result = int(dut.max_customers.value)
        
        # Verify
        if result == expected:
            print(f"Test {i+1}/{total}: PASS - n={n}, s1={s1}, s2={s2}, t={t_list}")
            print(f"  Expected: {expected}, Got: {result}")
            passed += 1
        else:
            print(f"Test {i+1}/{total}: FAIL - n={n}, s1={s1}, s2={s2}, t={t_list}")
            print(f"  Expected: {expected}, Got: {result}")
            # Also show Python solution for debugging
            py_result = solve_python(n, s1, s2, t_list)
            print(f"  Python solution: {py_result}")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
