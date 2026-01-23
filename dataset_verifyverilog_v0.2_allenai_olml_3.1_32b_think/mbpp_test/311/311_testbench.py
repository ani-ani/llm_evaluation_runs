import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_set_left_most_unset_bit(dut):
    """Test set_left_most_unset_bit module with various inputs"""
    
    # Test case 1: n = 10, expected = 14
    dut.n.value = 10
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = 14
    if result != expected:
        raise TestFailure(f"Test 1 failed: n=10, expected {expected}, got {result}")
    print(f"Test 1 passed: n=10, result={result}")
    
    # Test case 2: n = 12, expected = 14
    dut.n.value = 12
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = 14
    if result != expected:
        raise TestFailure(f"Test 2 failed: n=12, expected {expected}, got {result}")
    print(f"Test 2 passed: n=12, result={result}")
    
    # Test case 3: n = 15, expected = 15
    dut.n.value = 15
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = 15
    if result != expected:
        raise TestFailure(f"Test 3 failed: n=15, expected {expected}, got {result}")
    print(f"Test 3 passed: n=15, result={result}")
    
    # Additional test: n = 0, expected = 1 (leftmost unset bit is bit 0)
    dut.n.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Test 4 failed: n=0, expected {expected}, got {result}")
    print(f"Test 4 passed: n=0, result={result}")
    
    # Additional test: n = 255 (0xFF), expected = 255
    dut.n.value = 255
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = 255
    if result != expected:
        raise TestFailure(f"Test 5 failed: n=255, expected {expected}, got {result}")
    print(f"Test 5 passed: n=255, result={result}")
    
    # Additional test: n = 65534 (0xFFFE), expected = 65535
    dut.n.value = 65534
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = 65535
    if result != expected:
        raise TestFailure(f"Test 6 failed: n=65534, expected {expected}, got {result}")
    print(f"Test 6 passed: n=65534, result={result}")
    
    # Additional test: n = 6 (0b110), expected = 7 (0b111)
    dut.n.value = 6
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = 7
    if result != expected:
        raise TestFailure(f"Test 7 failed: n=6, expected {expected}, got {result}")
    print(f"Test 7 passed: n=6, result={result}")
    
    # Additional test: n = 8 (0b1000), expected = 9 (0b1001)
    dut.n.value = 8
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = 9
    if result != expected:
        raise TestFailure(f"Test 8 failed: n=8, expected {expected}, got {result}")
    print(f"Test 8 passed: n=8, result={result}")
    
    print("
All 8 tests passed!")