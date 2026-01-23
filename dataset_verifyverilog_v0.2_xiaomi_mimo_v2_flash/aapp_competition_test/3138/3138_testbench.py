import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
def test_arithmetic_book(dut):
    """Test arithmetic book range selection"""
    
    # Test case 1: n=5, [2,2,1,2,3]
    dut.n.value = 5
    dut.numbers[0].value = 2
    dut.numbers[1].value = 2
    dut.numbers[2].value = 1
    dut.numbers[3].value = 2
    dut.numbers[4].value = 3
    # Fill remaining with 1
    for i in range(5, 16):
        dut.numbers[i].value = 1
    
    await Timer(10, units='ns')
    assert dut.count.value == 2, f"Test 1 failed: expected 2, got {int(dut.count.value)}"
    print(f"Test 1 passed: n=5, array=[2,2,1,2,3], count={int(dut.count.value)}")
    
    # Test case 2: n=8, [1,2,4,1,1,2,5,1]
    dut.n.value = 8
    dut.numbers[0].value = 1
    dut.numbers[1].value = 2
    dut.numbers[2].value = 4
    dut.numbers[3].value = 1
    dut.numbers[4].value = 1
    dut.numbers[5].value = 2
    dut.numbers[6].value = 5
    dut.numbers[7].value = 1
    # Fill remaining with 1
    for i in range(8, 16):
        dut.numbers[i].value = 1
    
    await Timer(10, units='ns')
    assert dut.count.value == 4, f"Test 2 failed: expected 4, got {int(dut.count.value)}"
    print(f"Test 2 passed: n=8, array=[1,2,4,1,1,2,5,1], count={int(dut.count.value)}")
    
    # Test case 3: n=4, [5,6,7,8]
    dut.n.value = 4
    dut.numbers[0].value = 5
    dut.numbers[1].value = 6
    dut.numbers[2].value = 7
    dut.numbers[3].value = 8
    # Fill remaining with 1
    for i in range(4, 16):
        dut.numbers[i].value = 1
    
    await Timer(10, units='ns')
    assert dut.count.value == 0, f"Test 3 failed: expected 0, got {int(dut.count.value)}"
    print(f"Test 3 passed: n=4, array=[5,6,7,8], count={int(dut.count.value)}")
    
    # Test case 4: n=3, [1,2,3] (additional test)
    dut.n.value = 3
    dut.numbers[0].value = 1
    dut.numbers[1].value = 2
    dut.numbers[2].value = 3
    for i in range(3, 16):
        dut.numbers[i].value = 1
    
    await Timer(10, units='ns')
    assert dut.count.value == 0, f"Test 4 failed: expected 0, got {int(dut.count.value)}"
    print(f"Test 4 passed: n=3, array=[1,2,3], count={int(dut.count.value)}")
    
    # Test case 5: n=2, [1,1] (edge case, should be 1)
    dut.n.value = 2
    dut.numbers[0].value = 1
    dut.numbers[1].value = 1
    for i in range(2, 16):
        dut.numbers[i].value = 1
    
    await Timer(10, units='ns')
    assert dut.count.value == 1, f"Test 5 failed: expected 1, got {int(dut.count.value)}"
    print(f"Test 5 passed: n=2, array=[1,1], count={int(dut.count.value)}")
    
    print(f"
Summary: 5/5 tests passed")