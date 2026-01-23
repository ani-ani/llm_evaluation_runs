import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def compute_expected(data):
    """Compute expected product of unique elements (Python reference)"""
    seen = set()
    product = 1
    for x in data:
        if x not in seen:
            seen.add(x)
            product *= x
    return product

@cocotb.test()
async def test_unique_product(dut):
    """Test the unique_product module"""
    
    # Test cases: (input_list, expected_product)
    # Note: Python handles big integers, so we compare against that.
    # But if product > 2^32-1, we expect valid=0.
    
    test_cases = [
        ([10, 20, 30, 40, 20, 50, 60, 40], 720000000), # Test 1
        ([1, 2, 3, 1, 0, 0, 0, 0], 6),                # Test 2 adapted
        ([7, 8, 9, 0, 1, 1, 0, 0], 0),                # Test 3 adapted
        ([1, 1, 1, 1, 1, 1, 1, 1], 1),                # All duplicates
        ([255, 255, 255, 255, 255, 255, 255, 255], 255), # Single unique max
        ([2, 3, 5, 7, 11, 13, 17, 19], 9699690),     # Primes
        ([255, 254, 253, 252, 251, 1, 2, 3], None),   # Overflow case
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_list, expected) in enumerate(test_cases):
        # Drive inputs
        for j in range(8):
            dut.data[j].value = input_list[j]
        
        # Wait for combinational logic to settle
        # Using a small delay is safer for simulation
        await Timer(10, units='ns')
        
        # Read outputs
        product = int(dut.product.value)
        valid = int(dut.valid.value)
        
        # Check
        if expected is None:
            # Overflow case
            if valid == 0:
                print(f"Test {i+1} PASS: Input {input_list}, Overflow detected as expected")
                passed += 1
            else:
                print(f"Test {i+1} FAIL: Input {input_list}, Expected overflow but got valid={valid}, product={product}")
        else:
            if valid == 1 and product == expected:
                print(f"Test {i+1} PASS: Input {input_list}, Product={product}")
                passed += 1
            else:
                print(f"Test {i+1} FAIL: Input {input_list}, Expected product={expected}, valid=1. Got product={product}, valid={valid}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")