import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_concatenate(dut):
    """Test concatenation of fixed-width string arrays"""
    
    # Test case 1: Empty (count=0)
    dut.strings.value = [0, 0, 0, 0, 0]
    dut.count.value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 1 failed: expected 0, got {dut.result.value}"
    assert dut.length.value == 0, f"Test 1 failed: expected length 0, got {dut.length.value}"
    print("Test 1 passed: Empty concatenation")
    
    # Test case 2: Three chars 'x','y','z'
    # 'x'=0x78, 'y'=0x79, 'z'=0x7A
    dut.strings.value = [ord('x'), ord('y'), ord('z'), 0, 0]
    dut.count.value = 3
    await Timer(10, units='ns')
    expected = (ord('x') << 32) | (ord('y') << 24) | (ord('z') << 16)
    assert dut.result.value == expected, f"Test 2 failed: expected 0x{expected:010X}, got 0x{dut.result.value:010X}"
    assert dut.length.value == 3, f"Test 2 failed: expected length 3, got {dut.length.value}"
    print("Test 2 passed: 'x','y','z' concatenation")
    
    # Test case 3: Five chars 'x','y','z','w','k'
    dut.strings.value = [ord('x'), ord('y'), ord('z'), ord('w'), ord('k')]
    dut.count.value = 5
    await Timer(10, units='ns')
    expected = (ord('x') << 32) | (ord('y') << 24) | (ord('z') << 16) | (ord('w') << 8) | ord('k')
    assert dut.result.value == expected, f"Test 3 failed: expected 0x{expected:010X}, got 0x{dut.result.value:010X}"
    assert dut.length.value == 5, f"Test 3 failed: expected length 5, got {dut.length.value}"
    print("Test 3 passed: 'x','y','z','w','k' concatenation")
    
    # Test case 4: Single char 'a'
    dut.strings.value = [ord('a'), 0, 0, 0, 0]
    dut.count.value = 1
    await Timer(10, units='ns')
    expected = ord('a') << 32
    assert dut.result.value == expected, f"Test 4 failed: expected 0x{expected:010X}, got 0x{dut.result.value:010X}"
    assert dut.length.value == 1, f"Test 4 failed: expected length 1, got {dut.length.value}"
    print("Test 4 passed: Single char 'a'")
    
    # Test case 5: Two chars 'H','i'
    dut.strings.value = [ord('H'), ord('i'), 0, 0, 0]
    dut.count.value = 2
    await Timer(10, units='ns')
    expected = (ord('H') << 32) | (ord('i') << 24)
    assert dut.result.value == expected, f"Test 5 failed: expected 0x{expected:010X}, got 0x{dut.result.value:010X}"
    assert dut.length.value == 2, f"Test 5 failed: expected length 2, got {dut.length.value}"
    print("Test 5 passed: 'H','i' concatenation")
    
    print("
All 5 tests passed!")
