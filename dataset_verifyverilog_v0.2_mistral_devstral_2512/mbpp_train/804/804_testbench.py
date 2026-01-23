import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_product_even_checker(dut):
    """Test product even checker module"""
    
    # Initialize inputs
    dut.numbers.value = 0
    dut.valid_count.value = 0
    
    # Wait a bit
    await Timer(10, units='ns')
    
    test_cases = [
        # (numbers, valid_count, expected_result, description)
        ([1, 2, 3], 3, 1, "Test 1: [1,2,3] - contains 2 (even)"),
        ([1, 2, 1, 4], 4, 1, "Test 2: [1,2,1,4] - contains 2 and 4 (even)"),
        ([1, 1], 2, 0, "Test 3: [1,1] - all odd"),
        ([3, 5, 7], 3, 0, "Test 4: [3,5,7] - all odd"),
        ([2], 1, 1, "Test 5: [2] - single even"),
        ([1, 3, 5, 7, 9, 11, 13, 15], 8, 0, "Test 6: [1,3,5,7,9,11,13,15] - all odd 8 numbers"),
        ([1, 3, 5, 7, 9, 11, 13, 2], 8, 1, "Test 7: [1,3,5,7,9,11,13,2] - last one even"),
        ([0, 1, 1], 3, 1, "Test 8: [0,1,1] - contains 0 (even)"),
        ([4, 6, 8, 10, 12, 14, 16, 18], 8, 1, "Test 9: all even numbers"),
    ]
    
    passed = 0
    failed = 0
    
    for numbers, valid_count, expected, description in test_cases:
        # Prepare array for 8 elements
        dut.valid_count.value = valid_count
        
        # Set numbers array
        for i in range(8):
            if i < valid_count:
                dut.numbers[i].value = numbers[i]
            else:
                dut.numbers[i].value = 0
        
        await Timer(10, units='ns')
        
        result = int(dut.is_even.value)
        
        if result == expected:
            print(f"✓ PASS: {description} => is_even={result}")
            passed += 1
        else:
            print(f"✗ FAIL: {description} => Expected {expected}, got {result}")
            failed += 1
    
    print(f"
=== Summary: {passed}/{len(test_cases)} tests passed ===")
    assert failed == 0, f"{failed} test(s) failed"
