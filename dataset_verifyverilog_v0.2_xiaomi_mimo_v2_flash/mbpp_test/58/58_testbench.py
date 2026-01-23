import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_opposite_signs(dut):
    """Test that opposite_signs correctly identifies opposite sign integers"""
    
    # Test case 1: 1 and -2 (opposite signs)
    dut.x.value = 1
    dut.y.value = -2
    await Timer(10, units='ns')
    assert dut.opposite.value == 1, f"Test 1 failed: x=1, y=-2, expected opposite=1, got {dut.opposite.value}"
    print("Test 1 passed: 1 and -2 have opposite signs")
    
    # Test case 2: 3 and 2 (same signs, both positive)
    dut.x.value = 3
    dut.y.value = 2
    await Timer(10, units='ns')
    assert dut.opposite.value == 0, f"Test 2 failed: x=3, y=2, expected opposite=0, got {dut.opposite.value}"
    print("Test 2 passed: 3 and 2 do not have opposite signs")
    
    # Test case 3: -10 and -10 (same signs, both negative)
    dut.x.value = -10
    dut.y.value = -10
    await Timer(10, units='ns')
    assert dut.opposite.value == 0, f"Test 3 failed: x=-10, y=-10, expected opposite=0, got {dut.opposite.value}"
    print("Test 3 passed: -10 and -10 do not have opposite signs")
    
    # Test case 4: -2 and 2 (opposite signs)
    dut.x.value = -2
    dut.y.value = 2
    await Timer(10, units='ns')
    assert dut.opposite.value == 1, f"Test 4 failed: x=-2, y=2, expected opposite=1, got {dut.opposite.value}"
    print("Test 4 passed: -2 and 2 have opposite signs")
    
    # Additional edge cases
    # Test case 5: 0 and 5 (positive and zero - same sign convention)
    dut.x.value = 0
    dut.y.value = 5
    await Timer(10, units='ns')
    # Zero is not negative, so 0 and 5 are both "positive" - same sign
    assert dut.opposite.value == 0, f"Test 5 failed: x=0, y=5, expected opposite=0, got {dut.opposite.value}"
    print("Test 5 passed: 0 and 5 do not have opposite signs")
    
    # Test case 6: 0 and -1 (zero and negative)
    dut.x.value = 0
    dut.y.value = -1
    await Timer(10, units='ns')
    assert dut.opposite.value == 1, f"Test 6 failed: x=0, y=-1, expected opposite=1, got {dut.opposite.value}"
    print("Test 6 passed: 0 and -1 have opposite signs")
    
    # Test case 7: 127 and -128 (max and min values)
    dut.x.value = 127
    dut.y.value = -128
    await Timer(10, units='ns')
    assert dut.opposite.value == 1, f"Test 7 failed: x=127, y=-128, expected opposite=1, got {dut.opposite.value}"
    print("Test 7 passed: 127 and -128 have opposite signs")
    
    # Test case 8: -128 and -127 (both negative)
    dut.x.value = -128
    dut.y.value = -127
    await Timer(10, units='ns')
    assert dut.opposite.value == 0, f"Test 8 failed: x=-128, y=-127, expected opposite=0, got {dut.opposite.value}"
    print("Test 8 passed: -128 and -127 do not have opposite signs")
    
    # Test case 9: 127 and 126 (both positive)
    dut.x.value = 127
    dut.y.value = 126
    await Timer(10, units='ns')
    assert dut.opposite.value == 0, f"Test 9 failed: x=127, y=126, expected opposite=0, got {dut.opposite.value}"
    print("Test 9 passed: 127 and 126 do not have opposite signs")
    
    print("
All 9 tests passed successfully!")