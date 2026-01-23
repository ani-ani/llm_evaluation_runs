import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_find_min(dut):
    """Test find_min module with various test cases"""
    
    # Test 1: Basic test from example
    dut.data_in[0] = 10
    dut.data_in[1] = 20
    dut.data_in[2] = 1
    dut.data_in[3] = 45
    dut.data_in[4] = 99
    dut.data_in[5] = 0
    dut.data_in[6] = 0
    dut.data_in[7] = 0
    
    await Timer(10, units='ns')
    
    assert dut.min_value.value == 1, f"Test 1 failed: expected 1, got {int(dut.min_value.value)}"
    print("Test 1 passed: [10, 20, 1, 45, 99, 0, 0, 0] -> min = 1")
    
    # Test 2: Already sorted ascending
    dut.data_in[0] = 1
    dut.data_in[1] = 2
    dut.data_in[2] = 3
    dut.data_in[3] = 0
    dut.data_in[4] = 0
    dut.data_in[5] = 0
    dut.data_in[6] = 0
    dut.data_in[7] = 0
    
    await Timer(10, units='ns')
    
    assert dut.min_value.value == 1, f"Test 2 failed: expected 1, got {int(dut.min_value.value)}"
    print("Test 2 passed: [1, 2, 3, 0, 0, 0, 0, 0] -> min = 1")
    
    # Test 3: Non-sequential values
    dut.data_in[0] = 45
    dut.data_in[1] = 46
    dut.data_in[2] = 50
    dut.data_in[3] = 60
    dut.data_in[4] = 0
    dut.data_in[5] = 0
    dut.data_in[6] = 0
    dut.data_in[7] = 0
    
    await Timer(10, units='ns')
    
    assert dut.min_value.value == 45, f"Test 3 failed: expected 45, got {int(dut.min_value.value)}"
    print("Test 3 passed: [45, 46, 50, 60, 0, 0, 0, 0] -> min = 45")
    
    # Test 4: Minimum at end
    dut.data_in[0] = 100
    dut.data_in[1] = 200
    dut.data_in[2] = 50
    dut.data_in[3] = 75
    dut.data_in[4] = 10
    dut.data_in[5] = 250
    dut.data_in[6] = 300
    dut.data_in[7] = 5
    
    await Timer(10, units='ns')
    
    assert dut.min_value.value == 5, f"Test 4 failed: expected 5, got {int(dut.min_value.value)}"
    print("Test 4 passed: [100, 200, 50, 75, 10, 250, 300, 5] -> min = 5")
    
    # Test 5: All same values
    dut.data_in[0] = 42
    dut.data_in[1] = 42
    dut.data_in[2] = 42
    dut.data_in[3] = 42
    dut.data_in[4] = 42
    dut.data_in[5] = 42
    dut.data_in[6] = 42
    dut.data_in[7] = 42
    
    await Timer(10, units='ns')
    
    assert dut.min_value.value == 42, f"Test 5 failed: expected 42, got {int(dut.min_value.value)}"
    print("Test 5 passed: [42, 42, 42, 42, 42, 42, 42, 42] -> min = 42")
    
    # Test 6: With zeros in middle
    dut.data_in[0] = 100
    dut.data_in[1] = 0
    dut.data_in[2] = 50
    dut.data_in[3] = 75
    dut.data_in[4] = 25
    dut.data_in[5] = 0
    dut.data_in[6] = 0
    dut.data_in[7] = 0
    
    await Timer(10, units='ns')
    
    assert dut.min_value.value == 0, f"Test 6 failed: expected 0, got {int(dut.min_value.value)}"
    print("Test 6 passed: [100, 0, 50, 75, 25, 0, 0, 0] -> min = 0")
    
    print("
All tests passed!")