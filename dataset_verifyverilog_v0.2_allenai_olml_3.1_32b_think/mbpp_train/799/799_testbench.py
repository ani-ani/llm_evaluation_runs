import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_bit_rotate_left(dut):
    """Test left bit rotation on 32-bit numbers"""
    
    # Test case 1: left_rotate(16, 2) == 64
    dut.data_in.value = 16
    dut.rotate_bits.value = 2
    await Timer(10, units='ns')
    result = int(dut.result.value)
    assert result == 64, f"Test 1 failed: expected 64, got {result}"
    print(f"Test 1 passed: left_rotate(16, 2) = {result}")
    
    # Test case 2: left_rotate(10, 2) == 40
    dut.data_in.value = 10
    dut.rotate_bits.value = 2
    await Timer(10, units='ns')
    result = int(dut.result.value)
    assert result == 40, f"Test 2 failed: expected 40, got {result}"
    print(f"Test 2 passed: left_rotate(10, 2) = {result}")
    
    # Test case 3: left_rotate(99, 3) == 792
    dut.data_in.value = 99
    dut.rotate_bits.value = 3
    await Timer(10, units='ns')
    result = int(dut.result.value)
    assert result == 792, f"Test 3 failed: expected 792, got {result}"
    print(f"Test 3 passed: left_rotate(99, 3) = {result}")
    
    # Test case 4: left_rotate(0b0001, 3) == 0b1000
    dut.data_in.value = 0b0001
    dut.rotate_bits.value = 3
    await Timer(10, units='ns')
    result = int(dut.result.value)
    assert result == 0b1000, f"Test 4 failed: expected 8, got {result}"
    print(f"Test 4 passed: left_rotate(0b0001, 3) = {result:032b}")
    
    # Test case 5: left_rotate(0b0101, 3) == 0b101000
    dut.data_in.value = 0b0101
    dut.rotate_bits.value = 3
    await Timer(10, units='ns')
    result = int(dut.result.value)
    assert result == 0b101000, f"Test 5 failed: expected 40, got {result}"
    print(f"Test 5 passed: left_rotate(0b0101, 3) = {result:032b}")
    
    # Test case 6: left_rotate(0b11101, 3) == 0b11101000
    dut.data_in.value = 0b11101
    dut.rotate_bits.value = 3
    await Timer(10, units='ns')
    result = int(dut.result.value)
    assert result == 0b11101000, f"Test 6 failed: expected 232, got {result}"
    print(f"Test 6 passed: left_rotate(0b11101, 3) = {result:032b}")
    
    # Test case 7: Edge case - rotate by 0
    dut.data_in.value = 12345
    dut.rotate_bits.value = 0
    await Timer(10, units='ns')
    result = int(dut.result.value)
    assert result == 12345, f"Test 7 failed: expected 12345, got {result}"
    print(f"Test 7 passed: left_rotate(12345, 0) = {result}")
    
    # Test case 8: Edge case - rotate by 31
    dut.data_in.value = 0x80000000
    dut.rotate_bits.value = 31
    await Timer(10, units='ns')
    result = int(dut.result.value)
    assert result == 0x40000000, f"Test 8 failed: expected 0x40000000, got {result:08x}"
    print(f"Test 8 passed: left_rotate(0x80000000, 31) = {result:08x}")
    
    # Test case 9: Full 32-bit rotation
    dut.data_in.value = 0x12345678
    dut.rotate_bits.value = 4
    await Timer(10, units='ns')
    result = int(dut.result.value)
    expected = 0x23456781  # 0x12345678 << 4 with wrap
    assert result == expected, f"Test 9 failed: expected {expected:08x}, got {result:08x}"
    print(f"Test 9 passed: left_rotate(0x12345678, 4) = {result:08x}")
    
    # Test case 10: All bits set
    dut.data_in.value = 0xFFFFFFFF
    dut.rotate_bits.value = 8
    await Timer(10, units='ns')
    result = int(dut.result.value)
    assert result == 0xFFFFFFFF, f"Test 10 failed: expected 0xFFFFFFFF, got {result:08x}"
    print(f"Test 10 passed: left_rotate(0xFFFFFFFF, 8) = {result:08x}")
    
    print("
=== All 10 tests passed! ===")
}