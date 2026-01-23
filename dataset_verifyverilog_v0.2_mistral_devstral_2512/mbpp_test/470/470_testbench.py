import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_pairwise_add(dut):
    """Test pairwise addition of neighboring elements"""
    
    # Test Case 1: (1, 5, 7, 8, 10) -> (6, 12, 15, 18)
    dut.in0.value = 1
    dut.in1.value = 5
    dut.in2.value = 7
    dut.in3.value = 8
    dut.in4.value = 10
    await Timer(10, units='ns')
    
    assert dut.out0.value == 6, f"Test 1 failed: out0 = {dut.out0.value}, expected 6"
    assert dut.out1.value == 12, f"Test 1 failed: out1 = {dut.out1.value}, expected 12"
    assert dut.out2.value == 15, f"Test 1 failed: out2 = {dut.out2.value}, expected 15"
    assert dut.out3.value == 18, f"Test 1 failed: out3 = {dut.out3.value}, expected 18"
    print("Test 1 passed: (1,5,7,8,10) -> (6,12,15,18)")
    
    # Test Case 2: (2, 6, 8, 9, 11) -> (8, 14, 17, 20)
    dut.in0.value = 2
    dut.in1.value = 6
    dut.in2.value = 8
    dut.in3.value = 9
    dut.in4.value = 11
    await Timer(10, units='ns')
    
    assert dut.out0.value == 8, f"Test 2 failed: out0 = {dut.out0.value}, expected 8"
    assert dut.out1.value == 14, f"Test 2 failed: out1 = {dut.out1.value}, expected 14"
    assert dut.out2.value == 17, f"Test 2 failed: out2 = {dut.out2.value}, expected 17"
    assert dut.out3.value == 20, f"Test 2 failed: out3 = {dut.out3.value}, expected 20"
    print("Test 2 passed: (2,6,8,9,11) -> (8,14,17,20)")
    
    # Test Case 3: (3, 7, 9, 10, 12) -> (10, 16, 19, 22)
    dut.in0.value = 3
    dut.in1.value = 7
    dut.in2.value = 9
    dut.in3.value = 10
    dut.in4.value = 12
    await Timer(10, units='ns')
    
    assert dut.out0.value == 10, f"Test 3 failed: out0 = {dut.out0.value}, expected 10"
    assert dut.out1.value == 16, f"Test 3 failed: out1 = {dut.out1.value}, expected 16"
    assert dut.out2.value == 19, f"Test 3 failed: out2 = {dut.out2.value}, expected 19"
    assert dut.out3.value == 22, f"Test 3 failed: out3 = {dut.out3.value}, expected 22"
    print("Test 3 passed: (3,7,9,10,12) -> (10,16,19,22)")
    
    # Edge Case: Zero values
    dut.in0.value = 0
    dut.in1.value = 0
    dut.in2.value = 0
    dut.in3.value = 0
    dut.in4.value = 0
    await Timer(10, units='ns')
    
    assert dut.out0.value == 0, f"Edge case failed: out0 = {dut.out0.value}, expected 0"
    assert dut.out1.value == 0, f"Edge case failed: out1 = {dut.out1.value}, expected 0"
    assert dut.out2.value == 0, f"Edge case failed: out2 = {dut.out2.value}, expected 0"
    assert dut.out3.value == 0, f"Edge case failed: out3 = {dut.out3.value}, expected 0"
    print("Edge case passed: all zeros")
    
    # Edge Case: Maximum values (before overflow)
    dut.in0.value = 100
    dut.in1.value = 100
    dut.in2.value = 100
    dut.in3.value = 100
    dut.in4.value = 100
    await Timer(10, units='ns')
    
    assert dut.out0.value == 200, f"Edge case failed: out0 = {dut.out0.value}, expected 200"
    assert dut.out1.value == 200, f"Edge case failed: out1 = {dut.out1.value}, expected 200"
    assert dut.out2.value == 200, f"Edge case failed: out2 = {dut.out2.value}, expected 200"
    assert dut.out3.value == 200, f"Edge case failed: out3 = {dut.out3.value}, expected 200"
    print("Edge case passed: all 100s")
    
    print("
All 5 tests passed!")