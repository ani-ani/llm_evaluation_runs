import cocotb
from cocotb.triggers import Timer
import random

# Helper function to convert float to Q16.16 fixed-point integer
def float_to_q16_16(value):
    return int(value * 65536)

# Reference Python function
def has_close_elements_reference(numbers, threshold):
    n = len(numbers)
    for i in range(n):
        for j in range(i + 1, n):
            if abs(numbers[i] - numbers[j]) < threshold:
                return True
    return False

@cocotb.test()
async def test_has_close_elements(dut):
    """Test has_close_elements module with various test cases"""
    
    # Test case 1: Should return True (2.2 - 2.0 = 0.2 < 0.3)
    numbers1 = [1.0, 2.0, 3.9, 4.0, 5.0, 2.2, 0.0, 0.0]
    threshold1 = 0.3
    
    dut.numbers[0].value = float_to_q16_16(numbers1[0])
    dut.numbers[1].value = float_to_q16_16(numbers1[1])
    dut.numbers[2].value = float_to_q16_16(numbers1[2])
    dut.numbers[3].value = float_to_q16_16(numbers1[3])
    dut.numbers[4].value = float_to_q16_16(numbers1[4])
    dut.numbers[5].value = float_to_q16_16(numbers1[5])
    dut.numbers[6].value = float_to_q16_16(numbers1[6])
    dut.numbers[7].value = float_to_q16_16(numbers1[7])
    dut.threshold.value = float_to_q16_16(threshold1)
    
    await Timer(10, units='ns')
    
    expected = has_close_elements_reference(numbers1[:6], threshold1)
    actual = bool(int(dut.result.value))
    print(f"Test 1: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 1 failed: {actual} != {expected}"
    
    # Test case 2: Should return False (2.2 - 2.0 = 0.2 > 0.05)
    numbers2 = [1.0, 2.0, 3.9, 4.0, 5.0, 2.2, 0.0, 0.0]
    threshold2 = 0.05
    
    dut.numbers[0].value = float_to_q16_16(numbers2[0])
    dut.numbers[1].value = float_to_q16_16(numbers2[1])
    dut.numbers[2].value = float_to_q16_16(numbers2[2])
    dut.numbers[3].value = float_to_q16_16(numbers2[3])
    dut.numbers[4].value = float_to_q16_16(numbers2[4])
    dut.numbers[5].value = float_to_q16_16(numbers2[5])
    dut.numbers[6].value = float_to_q16_16(numbers2[6])
    dut.numbers[7].value = float_to_q16_16(numbers2[7])
    dut.threshold.value = float_to_q16_16(threshold2)
    
    await Timer(10, units='ns')
    
    expected = has_close_elements_reference(numbers2[:6], threshold2)
    actual = bool(int(dut.result.value))
    print(f"Test 2: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 2 failed: {actual} != {expected}"
    
    # Test case 3: Should return True (5.9 - 5.0 = 0.9 < 0.95)
    numbers3 = [1.0, 2.0, 5.9, 4.0, 5.0, 0.0, 0.0, 0.0]
    threshold3 = 0.95
    
    dut.numbers[0].value = float_to_q16_16(numbers3[0])
    dut.numbers[1].value = float_to_q16_16(numbers3[1])
    dut.numbers[2].value = float_to_q16_16(numbers3[2])
    dut.numbers[3].value = float_to_q16_16(numbers3[3])
    dut.numbers[4].value = float_to_q16_16(numbers3[4])
    dut.numbers[5].value = float_to_q16_16(numbers3[5])
    dut.numbers[6].value = float_to_q16_16(numbers3[6])
    dut.numbers[7].value = float_to_q16_16(numbers3[7])
    dut.threshold.value = float_to_q16_16(threshold3)
    
    await Timer(10, units='ns')
    
    expected = has_close_elements_reference(numbers3[:5], threshold3)
    actual = bool(int(dut.result.value))
    print(f"Test 3: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 3 failed: {actual} != {expected}"
    
    # Test case 4: Should return False (5.9 - 5.0 = 0.9 > 0.8)
    numbers4 = [1.0, 2.0, 5.9, 4.0, 5.0, 0.0, 0.0, 0.0]
    threshold4 = 0.8
    
    dut.numbers[0].value = float_to_q16_16(numbers4[0])
    dut.numbers[1].value = float_to_q16_16(numbers4[1])
    dut.numbers[2].value = float_to_q16_16(numbers4[2])
    dut.numbers[3].value = float_to_q16_16(numbers4[3])
    dut.numbers[4].value = float_to_q16_16(numbers4[4])
    dut.numbers[5].value = float_to_q16_16(numbers4[5])
    dut.numbers[6].value = float_to_q16_16(numbers4[6])
    dut.numbers[7].value = float_to_q16_16(numbers4[7])
    dut.threshold.value = float_to_q16_16(threshold4)
    
    await Timer(10, units='ns')
    
    expected = has_close_elements_reference(numbers4[:5], threshold4)
    actual = bool(int(dut.result.value))
    print(f"Test 4: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 4 failed: {actual} != {expected}"
    
    # Test case 5: Should return True (2.0 is duplicate)
    numbers5 = [1.0, 2.0, 3.0, 4.0, 5.0, 2.0, 0.0, 0.0]
    threshold5 = 0.1
    
    dut.numbers[0].value = float_to_q16_16(numbers5[0])
    dut.numbers[1].value = float_to_q16_16(numbers5[1])
    dut.numbers[2].value = float_to_q16_16(numbers5[2])
    dut.numbers[3].value = float_to_q16_16(numbers5[3])
    dut.numbers[4].value = float_to_q16_16(numbers5[4])
    dut.numbers[5].value = float_to_q16_16(numbers5[5])
    dut.numbers[6].value = float_to_q16_16(numbers5[6])
    dut.numbers[7].value = float_to_q16_16(numbers5[7])
    dut.threshold.value = float_to_q16_16(threshold5)
    
    await Timer(10, units='ns')
    
    expected = has_close_elements_reference(numbers5[:6], threshold5)
    actual = bool(int(dut.result.value))
    print(f"Test 5: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 5 failed: {actual} != {expected}"
    
    # Test case 6: Should return True
    numbers6 = [1.1, 2.2, 3.1, 4.1, 5.1, 0.0, 0.0, 0.0]
    threshold6 = 1.0
    
    dut.numbers[0].value = float_to_q16_16(numbers6[0])
    dut.numbers[1].value = float_to_q16_16(numbers6[1])
    dut.numbers[2].value = float_to_q16_16(numbers6[2])
    dut.numbers[3].value = float_to_q16_16(numbers6[3])
    dut.numbers[4].value = float_to_q16_16(numbers6[4])
    dut.numbers[5].value = float_to_q16_16(numbers6[5])
    dut.numbers[6].value = float_to_q16_16(numbers6[6])
    dut.numbers[7].value = float_to_q16_16(numbers6[7])
    dut.threshold.value = float_to_q16_16(threshold6)
    
    await Timer(10, units='ns')
    
    expected = has_close_elements_reference(numbers6[:5], threshold6)
    actual = bool(int(dut.result.value))
    print(f"Test 6: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 6 failed: {actual} != {expected}"
    
    # Test case 7: Should return False
    numbers7 = [1.1, 2.2, 3.1, 4.1, 5.1, 0.0, 0.0, 0.0]
    threshold7 = 0.5
    
    dut.numbers[0].value = float_to_q16_16(numbers7[0])
    dut.numbers[1].value = float_to_q16_16(numbers7[1])
    dut.numbers[2].value = float_to_q16_16(numbers7[2])
    dut.numbers[3].value = float_to_q16_16(numbers7[3])
    dut.numbers[4].value = float_to_q16_16(numbers7[4])
    dut.numbers[5].value = float_to_q16_16(numbers7[5])
    dut.numbers[6].value = float_to_q16_16(numbers7[6])
    dut.numbers[7].value = float_to_q16_16(numbers7[7])
    dut.threshold.value = float_to_q16_16(threshold7)
    
    await Timer(10, units='ns')
    
    expected = has_close_elements_reference(numbers7[:5], threshold7)
    actual = bool(int(dut.result.value))
    print(f"Test 7: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 7 failed: {actual} != {expected}"
    
    print("All tests passed!")
