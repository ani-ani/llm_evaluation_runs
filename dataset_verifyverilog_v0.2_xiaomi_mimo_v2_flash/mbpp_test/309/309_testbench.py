import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_maximum_basic(dut):
    """Test basic maximum functionality"""
    # Test 1: 5, 10 -> 10
    dut.a.value = 5
    dut.b.value = 10
    await Timer(10, units='ns')
    assert dut.max_result.value == 10, f"Test 1 failed: expected 10, got {dut.max_result.value}"
    print(f"Test 1 passed: maximum(5,10) = {dut.max_result.value}")
    
    # Test 2: -1, -2 -> -1
    dut.a.value = -1
    dut.b.value = -2
    await Timer(10, units='ns')
    assert dut.max_result.value == -1, f"Test 2 failed: expected -1, got {dut.max_result.value}"
    print(f"Test 2 passed: maximum(-1,-2) = {dut.max_result.value}")
    
    # Test 3: 9, 7 -> 9
    dut.a.value = 9
    dut.b.value = 7
    await Timer(10, units='ns')
    assert dut.max_result.value == 9, f"Test 3 failed: expected 9, got {dut.max_result.value}"
    print(f"Test 3 passed: maximum(9,7) = {dut.max_result.value}")
    
    # Additional edge cases
    # Test 4: Equal values
    dut.a.value = 5
    dut.b.value = 5
    await Timer(10, units='ns')
    assert dut.max_result.value == 5, f"Test 4 failed: expected 5, got {dut.max_result.value}"
    print(f"Test 4 passed: maximum(5,5) = {dut.max_result.value}")
    
    # Test 5: Max 16-bit values
    dut.a.value = 32767
    dut.b.value = 32766
    await Timer(10, units='ns')
    assert dut.max_result.value == 32767, f"Test 5 failed: expected 32767, got {dut.max_result.value}"
    print(f"Test 5 passed: maximum(32767,32766) = {dut.max_result.value}")
    
    # Test 6: Negative max
    dut.a.value = -10
    dut.b.value = -5
    await Timer(10, units='ns')
    assert dut.max_result.value == -5, f"Test 6 failed: expected -5, got {dut.max_result.value}"
    print(f"Test 6 passed: maximum(-10,-5) = {dut.max_result.value}")
    
    # Summary
    print("
All 6 tests passed successfully!")