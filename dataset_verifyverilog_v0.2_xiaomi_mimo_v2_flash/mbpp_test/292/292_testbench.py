import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_integer_division(dut):
    """Test integer division module with various cases"""
    
    # Test Case 1: 10 / 3 = 3
    dut.dividend.value = 10
    dut.divisor.value = 3
    await Timer(10, units='ns')
    assert int(dut.quotient.value) == 3, f"Test 1 failed: expected 3, got {int(dut.quotient.value)}"
    print("Test 1 passed: 10 / 3 = 3")
    
    # Test Case 2: 4 / 2 = 2
    dut.dividend.value = 4
    dut.divisor.value = 2
    await Timer(10, units='ns')
    assert int(dut.quotient.value) == 2, f"Test 2 failed: expected 2, got {int(dut.quotient.value)}"
    print("Test 2 passed: 4 / 2 = 2")
    
    # Test Case 3: 20 / 5 = 4
    dut.dividend.value = 20
    dut.divisor.value = 5
    await Timer(10, units='ns')
    assert int(dut.quotient.value) == 4, f"Test 3 failed: expected 4, got {int(dut.quotient.value)}"
    print("Test 3 passed: 20 / 5 = 4")
    
    # Test Case 4: Edge case - division by 1
    dut.dividend.value = 15
    dut.divisor.value = 1
    await Timer(10, units='ns')
    assert int(dut.quotient.value) == 15, f"Test 4 failed: expected 15, got {int(dut.quotient.value)}"
    print("Test 4 passed: 15 / 1 = 15")
    
    # Test Case 5: Large numbers
    dut.dividend.value = 65535
    dut.divisor.value = 256
    await Timer(10, units='ns')
    expected = 65535 // 256  # 255
    assert int(dut.quotient.value) == expected, f"Test 5 failed: expected {expected}, got {int(dut.quotient.value)}"
    print(f"Test 5 passed: 65535 / 256 = {expected}")
    
    print(f"
All tests passed: 5/5")