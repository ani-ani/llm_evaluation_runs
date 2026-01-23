import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_surfacearea_cube(dut):
    """Test surface area calculation for various cube sizes"""
    
    # Test case 1: side_length = 5, expected = 6 * 5 * 5 = 150
    dut.side_length.value = 5
    await Timer(10, units='ns')
    expected = 150
    actual = dut.surface_area.value
    print(f"Test 1: side_length=5, expected={expected}, actual={actual}")
    if actual != expected:
        raise TestFailure(f"Test 1 failed: expected {expected}, got {actual}")
    
    # Test case 2: side_length = 3, expected = 6 * 3 * 3 = 54
    dut.side_length.value = 3
    await Timer(10, units='ns')
    expected = 54
    actual = dut.surface_area.value
    print(f"Test 2: side_length=3, expected={expected}, actual={actual}")
    if actual != expected:
        raise TestFailure(f"Test 2 failed: expected {expected}, got {actual}")
    
    # Test case 3: side_length = 10, expected = 6 * 10 * 10 = 600
    dut.side_length.value = 10
    await Timer(10, units='ns')
    expected = 600
    actual = dut.surface_area.value
    print(f"Test 3: side_length=10, expected={expected}, actual={actual}")
    if actual != expected:
        raise TestFailure(f"Test 3 failed: expected {expected}, got {actual}")
    
    # Additional edge cases
    # Test case 4: side_length = 0, expected = 0
    dut.side_length.value = 0
    await Timer(10, units='ns')
    expected = 0
    actual = dut.surface_area.value
    print(f"Test 4: side_length=0, expected={expected}, actual={actual}")
    if actual != expected:
        raise TestFailure(f"Test 4 failed: expected {expected}, got {actual}")
    
    # Test case 5: side_length = 1, expected = 6 * 1 * 1 = 6
    dut.side_length.value = 1
    await Timer(10, units='ns')
    expected = 6
    actual = dut.surface_area.value
    print(f"Test 5: side_length=1, expected={expected}, actual={actual}")
    if actual != expected:
        raise TestFailure(f"Test 5 failed: expected {expected}, got {actual}")
    
    # Test case 6: side_length = 100, expected = 6 * 100 * 100 = 60000
    dut.side_length.value = 100
    await Timer(10, units='ns')
    expected = 60000
    actual = dut.surface_area.value
    print(f"Test 6: side_length=100, expected={expected}, actual={actual}")
    if actual != expected:
        raise TestFailure(f"Test 6 failed: expected {expected}, got {actual}")
    
    # Test case 7: side_length = 255, expected = 6 * 255 * 255 = 390150
    dut.side_length.value = 255
    await Timer(10, units='ns')
    expected = 390150
    actual = dut.surface_area.value
    print(f"Test 7: side_length=255, expected={expected}, actual={actual}")
    if actual != expected:
        raise TestFailure(f"Test 7 failed: expected {expected}, got {actual}")
    
    print(f"All tests passed!")