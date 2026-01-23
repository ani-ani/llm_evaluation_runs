import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_product_tuple(dut):
    """Test maximum absolute product calculation"""
    
    # Test Case 1: From original - scaled down
    # [(2, 7), (2, 6), (1, 8), (4, 9)] -> max abs product = 36
    dut.pair0_a.value = 2
    dut.pair0_b.value = 7
    dut.pair1_a.value = 2
    dut.pair1_b.value = 6
    dut.pair2_a.value = 1
    dut.pair2_b.value = 8
    dut.pair3_a.value = 4
    dut.pair3_b.value = 9
    await Timer(1, units='ns')
    result = int(dut.max_abs_product.value)
    expected = 36
    if result != expected:
        raise TestFailure(f"Test 1 failed: got {result}, expected {expected}")
    print(f"Test 1 passed: {result} == {expected}")
    
    # Test Case 2: All positive numbers
    # [(10, 20), (15, 2), (5, 10), (1, 1)] -> max abs product = 200
    dut.pair0_a.value = 10
    dut.pair0_b.value = 20
    dut.pair1_a.value = 15
    dut.pair1_b.value = 2
    dut.pair2_a.value = 5
    dut.pair2_b.value = 10
    dut.pair3_a.value = 1
    dut.pair3_b.value = 1
    await Timer(1, units='ns')
    result = int(dut.max_abs_product.value)
    expected = 200
    if result != expected:
        raise TestFailure(f"Test 2 failed: got {result}, expected {expected}")
    print(f"Test 2 passed: {result} == {expected}")
    
    # Test Case 3: From original - scaled down
    # [(11, 44), (10, 15), (20, 5), (12, 9)] -> max abs product = 484
    dut.pair0_a.value = 11
    dut.pair0_b.value = 44
    dut.pair1_a.value = 10
    dut.pair1_b.value = 15
    dut.pair2_a.value = 20
    dut.pair2_b.value = 5
    dut.pair3_a.value = 12
    dut.pair3_b.value = 9
    await Timer(1, units='ns')
    result = int(dut.max_abs_product.value)
    expected = 484
    if result != expected:
        raise TestFailure(f"Test 3 failed: got {result}, expected {expected}")
    print(f"Test 3 passed: {result} == {expected}")
    
    # Test Case 4: Mixed signs - absolute value test
    # [(-5, 8), (3, 7), (-10, -10), (1, 100)] -> max abs product = 100
    dut.pair0_a.value = -5 & 0xFFFF  # Two's complement
    dut.pair0_b.value = 8
    dut.pair1_a.value = 3
    dut.pair1_b.value = 7
    dut.pair2_a.value = -10 & 0xFFFF
    dut.pair2_b.value = -10 & 0xFFFF
    dut.pair3_a.value = 1
    dut.pair3_b.value = 100
    await Timer(1, units='ns')
    result = int(dut.max_abs_product.value)
    expected = 100
    if result != expected:
        raise TestFailure(f"Test 4 failed: got {result}, expected {expected}")
    print(f"Test 4 passed: {result} == {expected}")
    
    # Test Case 5: Edge case - negative product, absolute value
    # [(10, -10), (5, 3), (7, 8), (2, 2)] -> max abs product = 100
    dut.pair0_a.value = 10
    dut.pair0_b.value = -10 & 0xFFFF
    dut.pair1_a.value = 5
    dut.pair1_b.value = 3
    dut.pair2_a.value = 7
    dut.pair2_b.value = 8
    dut.pair3_a.value = 2
    dut.pair3_b.value = 2
    await Timer(1, units='ns')
    result = int(dut.max_abs_product.value)
    expected = 100
    if result != expected:
        raise TestFailure(f"Test 5 failed: got {result}, expected {expected}")
    print(f"Test 5 passed: {result} == {expected}")
    
    # Test Case 6: All zero
    # [(0, 0), (0, 0), (0, 0), (0, 0)] -> max abs product = 0
    dut.pair0_a.value = 0
    dut.pair0_b.value = 0
    dut.pair1_a.value = 0
    dut.pair1_b.value = 0
    dut.pair2_a.value = 0
    dut.pair2_b.value = 0
    dut.pair3_a.value = 0
    dut.pair3_b.value = 0
    await Timer(1, units='ns')
    result = int(dut.max_abs_product.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Test 6 failed: got {result}, expected {expected}")
    print(f"Test 6 passed: {result} == {expected}")
    
    print("
6/6 tests passed")