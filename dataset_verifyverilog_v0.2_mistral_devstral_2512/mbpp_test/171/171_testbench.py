import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_pentagon_perimeter(dut):
    """Test pentagon perimeter calculation for various side lengths"""
    
    # Test case 1: side length = 5
    dut.side_length.value = 5
    await Timer(10, units='ns')
    expected = 5 * 5
    if dut.perimeter.value != expected:
        raise TestFailure(f"Test 1 failed: side_length=5, expected={expected}, got={dut.perimeter.value}")
    print(f"Test 1 passed: side_length=5, perimeter={dut.perimeter.value}")
    
    # Test case 2: side length = 10
    dut.side_length.value = 10
    await Timer(10, units='ns')
    expected = 5 * 10
    if dut.perimeter.value != expected:
        raise TestFailure(f"Test 2 failed: side_length=10, expected={expected}, got={dut.perimeter.value}")
    print(f"Test 2 passed: side_length=10, perimeter={dut.perimeter.value}")
    
    # Test case 3: side length = 15
    dut.side_length.value = 15
    await Timer(10, units='ns')
    expected = 5 * 15
    if dut.perimeter.value != expected:
        raise TestFailure(f"Test 3 failed: side_length=15, expected={expected}, got={dut.perimeter.value}")
    print(f"Test 3 passed: side_length=15, perimeter={dut.perimeter.value}")
    
    # Additional edge case tests
    # Test case 4: side length = 0 (min value)
    dut.side_length.value = 0
    await Timer(10, units='ns')
    expected = 0
    if dut.perimeter.value != expected:
        raise TestFailure(f"Test 4 failed: side_length=0, expected={expected}, got={dut.perimeter.value}")
    print(f"Test 4 passed: side_length=0, perimeter={dut.perimeter.value}")
    
    # Test case 5: side length = 1 (edge case)
    dut.side_length.value = 1
    await Timer(10, units='ns')
    expected = 5 * 1
    if dut.perimeter.value != expected:
        raise TestFailure(f"Test 5 failed: side_length=1, expected={expected}, got={dut.perimeter.value}")
    print(f"Test 5 passed: side_length=1, perimeter={dut.perimeter.value}")
    
    # Test case 6: side length = 100 (larger value)
    dut.side_length.value = 100
    await Timer(10, units='ns')
    expected = 5 * 100
    if dut.perimeter.value != expected:
        raise TestFailure(f"Test 6 failed: side_length=100, expected={expected}, got={dut.perimeter.value}")
    print(f"Test 6 passed: side_length=100, perimeter={dut.perimeter.value}")
    
    print("All 6 tests passed!")