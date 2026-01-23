import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_rectangle_area(dut):
    """Test rectangle area calculation with various inputs"""
    
    # Test case 1: 10 * 20 = 200
    dut.length.value = 10
    dut.width.value = 20
    await Timer(10, units='ns')
    area = dut.area.value
    if area != 200:
        raise TestFailure(f"Test 1 failed: expected area=200, got {area}")
    print(f"Test 1 passed: length=10, width=20, area={area}")
    
    # Test case 2: 10 * 5 = 50
    dut.length.value = 10
    dut.width.value = 5
    await Timer(10, units='ns')
    area = dut.area.value
    if area != 50:
        raise TestFailure(f"Test 2 failed: expected area=50, got {area}")
    print(f"Test 2 passed: length=10, width=5, area={area}")
    
    # Test case 3: 4 * 2 = 8
    dut.length.value = 4
    dut.width.value = 2
    await Timer(10, units='ns')
    area = dut.area.value
    if area != 8:
        raise TestFailure(f"Test 3 failed: expected area=8, got {area}")
    print(f"Test 3 passed: length=4, width=2, area={area}")
    
    # Additional test: edge case with larger numbers
    dut.length.value = 1000
    dut.width.value = 200
    await Timer(10, units='ns')
    area = dut.area.value
    expected = 1000 * 200
    if area != expected:
        raise TestFailure(f"Test 4 failed: expected area={expected}, got {area}")
    print(f"Test 4 passed: length=1000, width=200, area={area}")
    
    # Additional test: multiplication by zero
    dut.length.value = 50
    dut.width.value = 0
    await Timer(10, units='ns')
    area = dut.area.value
    if area != 0:
        raise TestFailure(f"Test 5 failed: expected area=0, got {area}")
    print(f"Test 5 passed: length=50, width=0, area={area}")
    
    print("All tests passed: 5/5")