import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_min_of_three(dut):
    """Test min_of_three module with various test cases"""
    
    # Test case 1: 10, 20, 0 -> expected 0
    dut.a.value = 10
    dut.b.value = 20
    dut.c.value = 0
    await Timer(10, units='ns')
    assert dut.min.value.integer == 0, f"Test 1 failed: expected 0, got {dut.min.value.integer}"
    print("Test 1 passed: min_of_three(10, 20, 0) = 0")
    
    # Test case 2: 19, 15, 18 -> expected 15
    dut.a.value = 19
    dut.b.value = 15
    dut.c.value = 18
    await Timer(10, units='ns')
    assert dut.min.value.integer == 15, f"Test 2 failed: expected 15, got {dut.min.value.integer}"
    print("Test 2 passed: min_of_three(19, 15, 18) = 15")
    
    # Test case 3: -10, -20, -30 -> expected -30
    dut.a.value = -10
    dut.b.value = -20
    dut.c.value = -30
    await Timer(10, units='ns')
    assert dut.min.value.integer == -30, f"Test 3 failed: expected -30, got {dut.min.value.integer}"
    print("Test 3 passed: min_of_three(-10, -20, -30) = -30")
    
    # Additional edge cases
    # Test case 4: All equal values
    dut.a.value = 5
    dut.b.value = 5
    dut.c.value = 5
    await Timer(10, units='ns')
    assert dut.min.value.integer == 5, f"Test 4 failed: expected 5, got {dut.min.value.integer}"
    print("Test 4 passed: min_of_three(5, 5, 5) = 5")
    
    # Test case 5: Maximum positive values
    dut.a.value = 127
    dut.b.value = 126
    dut.c.value = 125
    await Timer(10, units='ns')
    assert dut.min.value.integer == 125, f"Test 5 failed: expected 125, got {dut.min.value.integer}"
    print("Test 5 passed: min_of_three(127, 126, 125) = 125")
    
    # Test case 6: Minimum negative values
    dut.a.value = -128
    dut.b.value = -127
    dut.c.value = -126
    await Timer(10, units='ns')
    assert dut.min.value.integer == -128, f"Test 6 failed: expected -128, got {dut.min.value.integer}"
    print("Test 6 passed: min_of_three(-128, -127, -126) = -128")
    
    # Test case 7: Mixed positive and negative
    dut.a.value = 10
    dut.b.value = -5
    dut.c.value = 0
    await Timer(10, units='ns')
    assert dut.min.value.integer == -5, f"Test 7 failed: expected -5, got {dut.min.value.integer}"
    print("Test 7 passed: min_of_three(10, -5, 0) = -5")
    
    print("
All 7/7 tests passed!")
