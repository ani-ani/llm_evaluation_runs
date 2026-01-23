import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_count_set_bits(dut):
    """Test the population count module with various inputs"""
    
    # Test case 1: 2 (binary 0000 0000 0000 0010) - 1 bit set
    dut.num.value = 2
    await Timer(10, units='ns')
    assert dut.count.value == 1, f"Test 1 failed: expected 1, got {dut.count.value}"
    print(f"Test 1 passed: count_Set_Bits(2) = {dut.count.value}")
    
    # Test case 2: 4 (binary 0000 0000 0000 0100) - 1 bit set
    dut.num.value = 4
    await Timer(10, units='ns')
    assert dut.count.value == 1, f"Test 2 failed: expected 1, got {dut.count.value}"
    print(f"Test 2 passed: count_Set_Bits(4) = {dut.count.value}")
    
    # Test case 3: 6 (binary 0000 0000 0000 0110) - 2 bits set
    dut.num.value = 6
    await Timer(10, units='ns')
    assert dut.count.value == 2, f"Test 3 failed: expected 2, got {dut.count.value}"
    print(f"Test 3 passed: count_Set_Bits(6) = {dut.count.value}")
    
    # Additional test cases
    # Test 4: 0 (all zeros) - 0 bits set
    dut.num.value = 0
    await Timer(10, units='ns')
    assert dut.count.value == 0, f"Test 4 failed: expected 0, got {dut.count.value}"
    print(f"Test 4 passed: count_Set_Bits(0) = {dut.count.value}")
    
    # Test 5: 255 (binary 0000 0000 1111 1111) - 8 bits set
    dut.num.value = 255
    await Timer(10, units='ns')
    assert dut.count.value == 8, f"Test 5 failed: expected 8, got {dut.count.value}"
    print(f"Test 5 passed: count_Set_Bits(255) = {dut.count.value}")
    
    # Test 6: 65535 (binary 1111 1111 1111 1111) - 16 bits set
    dut.num.value = 65535
    await Timer(10, units='ns')
    assert dut.count.value == 16, f"Test 6 failed: expected 16, got {dut.count.value}"
    print(f"Test 6 passed: count_Set_Bits(65535) = {dut.count.value}")
    
    # Test 7: 1 (binary 0000 0000 0000 0001) - 1 bit set
    dut.num.value = 1
    await Timer(10, units='ns')
    assert dut.count.value == 1, f"Test 7 failed: expected 1, got {dut.count.value}"
    print(f"Test 7 passed: count_Set_Bits(1) = {dut.count.value}")
    
    # Test 8: 3 (binary 0000 0000 0000 0011) - 2 bits set
    dut.num.value = 3
    await Timer(10, units='ns')
    assert dut.count.value == 2, f"Test 8 failed: expected 2, got {dut.count.value}"
    print(f"Test 8 passed: count_Set_Bits(3) = {dut.count.value}")
    
    # Test 9: 8 (binary 0000 0000 0000 1000) - 1 bit set
    dut.num.value = 8
    await Timer(10, units='ns')
    assert dut.count.value == 1, f"Test 9 failed: expected 1, got {dut.count.value}"
    print(f"Test 9 passed: count_Set_Bits(8) = {dut.count.value}")
    
    # Test 10: 7 (binary 0000 0000 0000 0111) - 3 bits set
    dut.num.value = 7
    await Timer(10, units='ns')
    assert dut.count.value == 3, f"Test 10 failed: expected 3, got {dut.count.value}"
    print(f"Test 10 passed: count_Set_Bits(7) = {dut.count.value}")
    
    # Summary
    print("
=== All 10 tests passed! ===")
