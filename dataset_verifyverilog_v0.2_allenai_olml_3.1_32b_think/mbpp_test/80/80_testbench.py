import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def calculate_tetrahedral(n):
    """Calculate tetrahedral number in Python for verification"""
    return (n * (n + 1) * (n + 2)) // 6

@cocotb.test()
async def test_tetrahedral_basic(dut):
    """Test basic tetrahedral number calculations"""
    
    # Test case 1: n=5, expected=35
    dut.n.value = 5
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_tetrahedral(5)
    if result != expected:
        raise TestFailure(f"Test 1 failed: n=5, expected={expected}, got={result}")
    print(f"Test 1 passed: n=5, result={result}")
    
    # Test case 2: n=6, expected=56
    dut.n.value = 6
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_tetrahedral(6)
    if result != expected:
        raise TestFailure(f"Test 2 failed: n=6, expected={expected}, got={result}")
    print(f"Test 2 passed: n=6, result={result}")
    
    # Test case 3: n=7, expected=84
    dut.n.value = 7
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_tetrahedral(7)
    if result != expected:
        raise TestFailure(f"Test 3 failed: n=7, expected={expected}, got={result}")
    print(f"Test 3 passed: n=7, result={result}")
    
    # Additional edge cases
    # Test n=1 (minimum meaningful input)
    dut.n.value = 1
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_tetrahedral(1)
    if result != expected:
        raise TestFailure(f"Edge case failed: n=1, expected={expected}, got={result}")
    print(f"Edge case passed: n=1, result={result}")
    
    # Test n=10 (larger value)
    dut.n.value = 10
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_tetrahedral(10)
    if result != expected:
        raise TestFailure(f"Edge case failed: n=10, expected={expected}, got={result}")
    print(f"Edge case passed: n=10, result={result}")
    
    # Test n=0 (boundary)
    dut.n.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = calculate_tetrahedral(0)
    if result != expected:
        raise TestFailure(f"Boundary case failed: n=0, expected={expected}, got={result}")
    print(f"Boundary case passed: n=0, result={result}")
    
    print("
All 6 tests passed!")
