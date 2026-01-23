import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_all_bits_unset_in_range(dut):
    """Test all_bits_unset_in_range module with various test cases"""
    
    # Test case 1: n=4 (binary 100), l=1, r=2
    # Range covers bits 0-1 (LSB). 4 = 0b100, bits 0-1 are both 0
    # Expected: True (1)
    dut.n.value = 4
    dut.l.value = 1
    dut.r.value = 2
    await Timer(1, units='ns')
    if dut.all_unset.value != 1:
        raise TestFailure(f"Test 1 failed: n=4, l=1, r=2. Expected all_unset=1, got {dut.all_unset.value}")
    print("Test 1 passed: n=4, l=1, r=2 -> all_unset=1")
    
    # Test case 2: n=17 (binary 10001), l=2, r=4
    # 17 = 0b10001, bits 1-3: bit1=0, bit2=0, bit3=1
    # Wait, need to verify: 17 in binary: 10001 (bits 0,4 set)
    # bits 1,2,3 = positions 1,2,3 (0-indexed: 1,2,3)
    # bit1=0, bit2=0, bit3=1 (since bit3 is set in 17)
    # So not all unset -> should be False
    # Let me recalculate: 17 = 0b10001, positions: bit0=1, bit1=0, bit2=0, bit3=0, bit4=1
    # Range l=2,r=4 covers bits 1,2,3 (0-indexed: 1,2,3)
    # All bits 1,2,3 are 0, so should be True
    dut.n.value = 17
    dut.l.value = 2
    dut.r.value = 4
    await Timer(1, units='ns')
    if dut.all_unset.value != 1:
        raise TestFailure(f"Test 2 failed: n=17, l=2, r=4. Expected all_unset=1, got {dut.all_unset.value}")
    print("Test 2 passed: n=17, l=2, r=4 -> all_unset=1")
    
    # Test case 3: n=39 (binary 100111), l=4, r=6
    # 39 = 0b100111, bits: bit0=1, bit1=1, bit2=1, bit3=0, bit4=0, bit5=1
    # Range l=4,r=6 covers bits 3,4,5 (0-indexed: 3,4,5)
    # bit3=0, bit4=0, bit5=1 -> not all unset
    # Expected: False (0)
    dut.n.value = 39
    dut.l.value = 4
    dut.r.value = 6
    await Timer(1, units='ns')
    if dut.all_unset.value != 0:
        raise TestFailure(f"Test 3 failed: n=39, l=4, r=6. Expected all_unset=0, got {dut.all_unset.value}")
    print("Test 3 passed: n=39, l=4, r=6 -> all_unset=0")
    
    # Additional test case 4: Edge case - single bit range, bit set
    # n=8 (0b1000), l=4, r=4 (just bit 3 in 0-indexed)
    # bit3 = 1, so not unset -> should be 0
    dut.n.value = 8
    dut.l.value = 4
    dut.r.value = 4
    await Timer(1, units='ns')
    if dut.all_unset.value != 0:
        raise TestFailure(f"Test 4 failed: n=8, l=4, r=4. Expected all_unset=0, got {dut.all_unset.value}")
    print("Test 4 passed: n=8, l=4, r=4 -> all_unset=0")
    
    # Additional test case 5: All bits in range unset
    # n=0, l=1, r=32 (all bits 0)
    # Should return 1
    dut.n.value = 0
    dut.l.value = 1
    dut.r.value = 32
    await Timer(1, units='ns')
    if dut.all_unset.value != 1:
        raise TestFailure(f"Test 5 failed: n=0, l=1, r=32. Expected all_unset=1, got {dut.all_unset.value}")
    print("Test 5 passed: n=0, l=1, r=32 -> all_unset=1")
    
    # Additional test case 6: Multiple bits set in range
    # n=12 (0b1100), l=1, r=3 (bits 0,1,2)
    # bit0=0, bit1=0, bit2=1 -> not all unset
    dut.n.value = 12
    dut.l.value = 1
    dut.r.value = 3
    await Timer(1, units='ns')
    if dut.all_unset.value != 0:
        raise TestFailure(f"Test 6 failed: n=12, l=1, r=3. Expected all_unset=0, got {dut.all_unset.value}")
    print("Test 6 passed: n=12, l=1, r=3 -> all_unset=0")
    
    print("
=== Summary: All 6 tests passed ===")
}