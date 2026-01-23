import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_tuple_to_int(dut):
    """Test tuple_to_int module with various inputs"""
    
    # Test case 1: 123 (digits 0,0,0,0,0,1,2,3)
    dut.digit_0.value = 3
    dut.digit_1.value = 2
    dut.digit_2.value = 1
    dut.digit_3.value = 0
    dut.digit_4.value = 0
    dut.digit_5.value = 0
    dut.digit_6.value = 0
    dut.digit_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 1: Input digits [0,0,0,0,0,1,2,3] -> Result: {result}")
    assert result == 123, f"Expected 123, got {result}"
    
    # Test case 2: 456 (digits 0,0,0,0,0,4,5,6)
    dut.digit_0.value = 6
    dut.digit_1.value = 5
    dut.digit_2.value = 4
    dut.digit_3.value = 0
    dut.digit_4.value = 0
    dut.digit_5.value = 0
    dut.digit_6.value = 0
    dut.digit_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 2: Input digits [0,0,0,0,0,4,5,6] -> Result: {result}")
    assert result == 456, f"Expected 456, got {result}"
    
    # Test case 3: 567 (digits 0,0,0,0,0,5,6,7)
    dut.digit_0.value = 7
    dut.digit_1.value = 6
    dut.digit_2.value = 5
    dut.digit_3.value = 0
    dut.digit_4.value = 0
    dut.digit_5.value = 0
    dut.digit_6.value = 0
    dut.digit_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 3: Input digits [0,0,0,0,0,5,6,7] -> Result: {result}")
    assert result == 567, f"Expected 567, got {result}"
    
    # Test case 4: 9999 (digits 0,0,0,0,9,9,9,9)
    dut.digit_0.value = 9
    dut.digit_1.value = 9
    dut.digit_2.value = 9
    dut.digit_3.value = 9
    dut.digit_4.value = 0
    dut.digit_5.value = 0
    dut.digit_6.value = 0
    dut.digit_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 4: Input digits [0,0,0,0,9,9,9,9] -> Result: {result}")
    assert result == 9999, f"Expected 9999, got {result}"
    
    # Test case 5: 12345678 (max 8 digits)
    dut.digit_0.value = 8
    dut.digit_1.value = 7
    dut.digit_2.value = 6
    dut.digit_3.value = 5
    dut.digit_4.value = 4
    dut.digit_5.value = 3
    dut.digit_6.value = 2
    dut.digit_7.value = 1
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 5: Input digits [1,2,3,4,5,6,7,8] -> Result: {result}")
    assert result == 12345678, f"Expected 12345678, got {result}"
    
    print("All 5 tests passed!")