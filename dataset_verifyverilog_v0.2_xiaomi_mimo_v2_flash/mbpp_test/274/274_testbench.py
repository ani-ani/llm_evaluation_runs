import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_even_binomial_sum(dut):
    """Test the even_binomial_sum module with multiple test cases"""
    
    # Test case 1: n=2, result should be 2 (2^1)
    dut.n.value = 2
    await Timer(1, units='ns')
    expected = 1 << (2 - 1)  # 2
    if dut.result.value != expected:
        raise TestFailure(f"Test 1 failed: n=2, expected {expected}, got {int(dut.result.value)}")
    print(f"Test 1 passed: n=2, result={int(dut.result.value)} (expected {expected})")
    
    # Test case 2: n=4, result should be 8 (2^3)
    dut.n.value = 4
    await Timer(1, units='ns')
    expected = 1 << (4 - 1)  # 8
    if dut.result.value != expected:
        raise TestFailure(f"Test 2 failed: n=4, expected {expected}, got {int(dut.result.value)}")
    print(f"Test 2 passed: n=4, result={int(dut.result.value)} (expected {expected})")
    
    # Test case 3: n=6, result should be 32 (2^5)
    dut.n.value = 6
    await Timer(1, units='ns')
    expected = 1 << (6 - 1)  # 32
    if dut.result.value != expected:
        raise TestFailure(f"Test 3 failed: n=6, expected {expected}, got {int(dut.result.value)}")
    print(f"Test 3 passed: n=6, result={int(dut.result.value)} (expected {expected})")
    
    # Test case 4: n=1, result should be 1 (2^0)
    dut.n.value = 1
    await Timer(1, units='ns')
    expected = 1 << (1 - 1)  # 1
    if dut.result.value != expected:
        raise TestFailure(f"Test 4 failed: n=1, expected {expected}, got {int(dut.result.value)}")
    print(f"Test 4 passed: n=1, result={int(dut.result.value)} (expected {expected})")
    
    # Test case 5: n=10, result should be 512 (2^9)
    dut.n.value = 10
    await Timer(1, units='ns')
    expected = 1 << (10 - 1)  # 512
    if dut.result.value != expected:
        raise TestFailure(f"Test 5 failed: n=10, expected {expected}, got {int(dut.result.value)}")
    print(f"Test 5 passed: n=10, result={int(dut.result.value)} (expected {expected})")
    
    # Test case 6: n=32 (max), result should be 2147483648 (2^31)
    dut.n.value = 32
    await Timer(1, units='ns')
    expected = 1 << (32 - 1)  # 2147483648
    if dut.result.value != expected:
        raise TestFailure(f"Test 6 failed: n=32, expected {expected}, got {int(dut.result.value)}")
    print(f"Test 6 passed: n=32, result={int(dut.result.value)} (expected {expected})")
    
    print("All 6 tests passed!")