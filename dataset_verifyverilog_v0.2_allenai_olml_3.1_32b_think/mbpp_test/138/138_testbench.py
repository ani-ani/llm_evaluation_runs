import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_powers_of_two_sum(dut):
    """Test if number can be represented as sum of non-zero powers of 2 (excluding 2^0)"""
    
    # Test case 1: 10 = 8 + 2 (both ≥ 2), should be True
    dut.num.value = 10
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 1 failed: 10 should be representable as 8+2"
    print(f"Test 1 passed: 10 -> {dut.result.value.value} (expected 1)")
    
    # Test case 2: 7 = 4+2+1 (includes 1), should be False
    dut.num.value = 7
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 2 failed: 7 cannot be represented without using 2^0"
    print(f"Test 2 passed: 7 -> {dut.result.value.value} (expected 0)")
    
    # Test case 3: 14 = 8+4+2 (all ≥ 2), should be True
    dut.num.value = 14
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 3 failed: 14 should be representable as 8+4+2"
    print(f"Test 3 passed: 14 -> {dut.result.value.value} (expected 1)")
    
    # Additional test cases
    # Test case 4: 0 (empty sum), should be False
    dut.num.value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 4 failed: 0 has no representation"
    print(f"Test 4 passed: 0 -> {dut.result.value.value} (expected 0)")
    
    # Test case 5: 2 = 2^1 (single power ≥ 2), should be False (not a sum)
    dut.num.value = 2
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 5 failed: 2 is a single power, not a sum"
    print(f"Test 5 passed: 2 -> {dut.result.value.value} (expected 0)")
    
    # Test case 6: 4 (single power), should be False
    dut.num.value = 4
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 6 failed: 4 is a single power"
    print(f"Test 6 passed: 4 -> {dut.result.value.value} (expected 0)")
    
    # Test case 7: 6 = 4+2, should be True
    dut.num.value = 6
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 7 failed: 6 should be representable as 4+2"
    print(f"Test 7 passed: 6 -> {dut.result.value.value} (expected 1)")
    
    # Test case 8: 1 = 2^0 (includes 2^0), should be False
    dut.num.value = 1
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 8 failed: 1 includes 2^0"
    print(f"Test 8 passed: 1 -> {dut.result.value.value} (expected 0)")
    
    # Test case 9: 12 = 8+4, should be True
    dut.num.value = 12
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 9 failed: 12 should be representable as 8+4"
    print(f"Test 9 passed: 12 -> {dut.result.value.value} (expected 1)")
    
    # Test case 10: 3 = 2+1 (includes 1), should be False
    dut.num.value = 3
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 10 failed: 3 includes 2^0"
    print(f"Test 10 passed: 3 -> {dut.result.value.value} (expected 0)")
    
    print("
All tests passed!")