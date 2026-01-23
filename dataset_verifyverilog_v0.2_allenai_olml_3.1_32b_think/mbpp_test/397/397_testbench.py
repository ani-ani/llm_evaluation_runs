import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_median_three(dut):
    """Test median of three numbers"""
    
    # Test case 1: 25, 55, 65 -> median 55
    dut.a.value = 25
    dut.b.value = 55
    dut.c.value = 65
    await Timer(10, units='ns')
    result = int(dut.median.value)
    print(f"Test 1: a=25, b=55, c=65 -> median={result}")
    if result != 55:
        raise TestFailure(f"Expected 55, got {result}")
    
    # Test case 2: 20, 10, 30 -> median 20
    dut.a.value = 20
    dut.b.value = 10
    dut.c.value = 30
    await Timer(10, units='ns')
    result = int(dut.median.value)
    print(f"Test 2: a=20, b=10, c=30 -> median={result}")
    if result != 20:
        raise TestFailure(f"Expected 20, got {result}")
    
    # Test case 3: 15, 45, 75 -> median 45
    dut.a.value = 15
    dut.b.value = 45
    dut.c.value = 75
    await Timer(10, units='ns')
    result = int(dut.median.value)
    print(f"Test 3: a=15, b=45, c=75 -> median={result}")
    if result != 45:
        raise TestFailure(f"Expected 45, got {result}")
    
    # Additional edge cases
    # Equal values
    dut.a.value = 30
    dut.b.value = 30
    dut.c.value = 30
    await Timer(10, units='ns')
    result = int(dut.median.value)
    print(f"Test 4: a=30, b=30, c=30 -> median={result}")
    if result != 30:
        raise TestFailure(f"Expected 30, got {result}")
    
    # Min value is median
    dut.a.value = 5
    dut.b.value = 10
    dut.c.value = 15
    await Timer(10, units='ns')
    result = int(dut.median.value)
    print(f"Test 5: a=5, b=10, c=15 -> median={result}")
    if result != 10:
        raise TestFailure(f"Expected 10, got {result}")
    
    # Max value is median
    dut.a.value = 100
    dut.b.value = 50
    dut.c.value = 75
    await Timer(10, units='ns')
    result = int(dut.median.value)
    print(f"Test 6: a=100, b=50, c=75 -> median={result}")
    if result != 75:
        raise TestFailure(f"Expected 75, got {result}")
    
    print("
6/6 tests passed!")