import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_largest_number_formed(dut):
    """Test finding largest number from digit list"""
    
    # Test 1: [1,2,3] -> 321 (pad with zeros for 8 inputs)
    dut.digit_0.value = 1
    dut.digit_1.value = 2
    dut.digit_2.value = 3
    dut.digit_3.value = 0
    dut.digit_4.value = 0
    dut.digit_5.value = 0
    dut.digit_6.value = 0
    dut.digit_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 1: [1,2,3] -> Expected 321, Got {result}")
    assert result == 321, f"Expected 321, got {result}"
    
    # Test 2: [4,5,6,1] -> 6541
    dut.digit_0.value = 4
    dut.digit_1.value = 5
    dut.digit_2.value = 6
    dut.digit_3.value = 1
    dut.digit_4.value = 0
    dut.digit_5.value = 0
    dut.digit_6.value = 0
    dut.digit_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 2: [4,5,6,1] -> Expected 6541, Got {result}")
    assert result == 6541, f"Expected 6541, got {result}"
    
    # Test 3: [1,2,3,9] -> 9321
    dut.digit_0.value = 1
    dut.digit_1.value = 2
    dut.digit_2.value = 3
    dut.digit_3.value = 9
    dut.digit_4.value = 0
    dut.digit_5.value = 0
    dut.digit_6.value = 0
    dut.digit_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 3: [1,2,3,9] -> Expected 9321, Got {result}")
    assert result == 9321, f"Expected 9321, got {result}"
    
    # Test 4: [9,9,1,2] -> 9921
    dut.digit_0.value = 9
    dut.digit_1.value = 9
    dut.digit_2.value = 1
    dut.digit_3.value = 2
    dut.digit_4.value = 0
    dut.digit_5.value = 0
    dut.digit_6.value = 0
    dut.digit_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 4: [9,9,1,2] -> Expected 9921, Got {result}")
    assert result == 9921, f"Expected 9921, got {result}"
    
    # Test 5: [0,0,1,2,3] -> 32100 (note: leading zeros but still largest)
    dut.digit_0.value = 0
    dut.digit_1.value = 0
    dut.digit_2.value = 1
    dut.digit_3.value = 2
    dut.digit_4.value = 3
    dut.digit_5.value = 0
    dut.digit_6.value = 0
    dut.digit_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    print(f"Test 5: [0,0,1,2,3] -> Expected 32100, Got {result}")
    assert result == 32100, f"Expected 32100, got {result}"
    
    print("
All 5/5 tests passed!")
