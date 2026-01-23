import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def popcount_binary(n):
    """Count number of 1 bits in binary representation"""
    return bin(n).count('1')

@cocotb.test()
async def test_bool_count(dut):
    """Test boolean counting module with various patterns"""
    
    # Test case 1: count([True,False,True]) -> 2
    # Pattern: 8'b00000101 (bits 0 and 2 set)
    dut.data.value = 0b00000101
    await Timer(1, units='ns')
    result = int(dut.count.value)
    expected = popcount_binary(0b00000101)
    if result != expected:
        raise TestFailure(f"Test 1 failed: Expected {expected}, got {result}")
    print(f"Test 1 passed: {result} true booleans")
    
    # Test case 2: count([False,False]) -> 0
    # Pattern: 8'b00000000
    dut.data.value = 0b00000000
    await Timer(1, units='ns')
    result = int(dut.count.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Test 2 failed: Expected {expected}, got {result}")
    print(f"Test 2 passed: {result} true booleans")
    
    # Test case 3: count([True,True,True]) -> 3
    # Pattern: 8'b00000111 (bits 0,1,2 set)
    dut.data.value = 0b00000111
    await Timer(1, units='ns')
    result = int(dut.count.value)
    expected = popcount_binary(0b00000111)
    if result != expected:
        raise TestFailure(f"Test 3 failed: Expected {expected}, got {result}")
    print(f"Test 3 passed: {result} true booleans")
    
    # Additional test cases for comprehensive coverage
    
    # Edge case: all true (8 bits)
    dut.data.value = 0b11111111
    await Timer(1, units='ns')
    result = int(dut.count.value)
    expected = 8
    if result != expected:
        raise TestFailure(f"All true test failed: Expected {expected}, got {result}")
    print(f"All true test passed: {result} true booleans")
    
    # Edge case: alternating pattern (4 bits)
    dut.data.value = 0b10101010
    await Timer(1, units='ns')
    result = int(dut.count.value)
    expected = 4
    if result != expected:
        raise TestFailure(f"Alternating test failed: Expected {expected}, got {result}")
    print(f"Alternating test passed: {result} true booleans")
    
    # Edge case: single bit set (high position)
    dut.data.value = 0b10000000
    await Timer(1, units='ns')
    result = int(dut.count.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Single high bit test failed: Expected {expected}, got {result}")
    print(f"Single high bit test passed: {result} true booleans")
    
    # Edge case: random pattern 0b11010011
    dut.data.value = 0b11010011
    await Timer(1, units='ns')
    result = int(dut.count.value)
    expected = popcount_binary(0b11010011)
    if result != expected:
        raise TestFailure(f"Random pattern test failed: Expected {expected}, got {result}")
    print(f"Random pattern test passed: {result} true booleans")
    
    print(f"
All tests completed: {7}/{7} passed")