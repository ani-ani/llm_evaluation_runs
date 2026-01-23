import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_closest_num(dut):
    """Test closest_num module with various inputs"""
    
    # Test case 1: N = 11, expected result = 10
    dut.N.value = 11
    await Timer(10, units='ns')
    assert dut.result.value == 10, f"Test 1 failed: N=11, expected 10, got {dut.result.value}"
    print("Test 1 passed: N=11, result=10")
    
    # Test case 2: N = 7, expected result = 6
    dut.N.value = 7
    await Timer(10, units='ns')
    assert dut.result.value == 6, f"Test 2 failed: N=7, expected 6, got {dut.result.value}"
    print("Test 2 passed: N=7, result=6")
    
    # Test case 3: N = 12, expected result = 11
    dut.N.value = 12
    await Timer(10, units='ns')
    assert dut.result.value == 11, f"Test 3 failed: N=12, expected 11, got {dut.result.value}"
    print("Test 3 passed: N=12, result=11")
    
    # Additional edge cases
    # Test case 4: N = 1, expected result = 0
    dut.N.value = 1
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 4 failed: N=1, expected 0, got {dut.result.value}"
    print("Test 4 passed: N=1, result=0")
    
    # Test case 5: N = 255, expected result = 254
    dut.N.value = 255
    await Timer(10, units='ns')
    assert dut.result.value == 254, f"Test 5 failed: N=255, expected 254, got {dut.result.value}"
    print("Test 5 passed: N=255, result=254")
    
    # Test case 6: N = 0, expected result = 255 (wrap around)
    dut.N.value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 255, f"Test 6 failed: N=0, expected 255, got {dut.result.value}"
    print("Test 6 passed: N=0, result=255")
    
    print("
All 6/6 tests passed!")