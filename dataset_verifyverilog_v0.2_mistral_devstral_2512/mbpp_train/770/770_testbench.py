import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_odd_fourth_power_sum(dut):
    """Test odd fourth power sum calculation"""
    
    # Test case 1: n=2, expected=82
    dut.n.value = 2
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = 82
    if result != expected:
        raise TestFailure(f"Test 1 failed: n=2, expected {expected}, got {result}")
    print(f"Test 1 passed: n=2, sum={result}")
    
    # Test case 2: n=3, expected=707
    dut.n.value = 3
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = 707
    if result != expected:
        raise TestFailure(f"Test 2 failed: n=3, expected {expected}, got {result}")
    print(f"Test 2 passed: n=3, sum={result}")
    
    # Test case 3: n=4, expected=3108
    dut.n.value = 4
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = 3108
    if result != expected:
        raise TestFailure(f"Test 3 failed: n=4, expected {expected}, got {result}")
    print(f"Test 3 passed: n=4, sum={result}")
    
    # Additional edge cases
    # n=1: 1^4 = 1
    dut.n.value = 1
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Test 4 failed: n=1, expected {expected}, got {result}")
    print(f"Test 4 passed: n=1, sum={result}")
    
    # n=5: 1+81+625+2401+6561 = 9669
    dut.n.value = 5
    await Timer(10, units='ns')
    result = int(dut.sum.value)
    expected = 9669
    if result != expected:
        raise TestFailure(f"Test 5 failed: n=5, expected {expected}, got {result}")
    print(f"Test 5 passed: n=5, sum={result}")
    
    print("All 5 tests passed!")