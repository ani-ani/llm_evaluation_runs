import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_check_all_empty(dut):
    """Test that all_empty correctly identifies when all array elements are zero"""
    
    # Test 1: All empty (all zeros) - should return 1
    dut.dicts[0] = 0
    dut.dicts[1] = 0
    dut.dicts[2] = 0
    dut.dicts[3] = 0
    dut.dicts[4] = 0
    dut.dicts[5] = 0
    dut.dicts[6] = 0
    dut.dicts[7] = 0
    await Timer(1, units='ns')
    assert dut.all_empty.value == 1, f"Test 1 failed: Expected 1 for all empty, got {dut.all_empty.value}"
    print("Test 1 passed: All empty arrays correctly identified")
    
    # Test 2: One non-empty element at position 0
    dut.dicts[0] = 1
    dut.dicts[1] = 0
    dut.dicts[2] = 0
    dut.dicts[3] = 0
    dut.dicts[4] = 0
    dut.dicts[5] = 0
    dut.dicts[6] = 0
    dut.dicts[7] = 0
    await Timer(1, units='ns')
    assert dut.all_empty.value == 0, f"Test 2 failed: Expected 0 for non-empty, got {dut.all_empty.value}"
    print("Test 2 passed: One non-empty element detected")
    
    # Test 3: Non-empty element at last position
    dut.dicts[0] = 0
    dut.dicts[1] = 0
    dut.dicts[2] = 0
    dut.dicts[3] = 0
    dut.dicts[4] = 0
    dut.dicts[5] = 0
    dut.dicts[6] = 0
    dut.dicts[7] = 255  # 0xFF
    await Timer(1, units='ns')
    assert dut.all_empty.value == 0, f"Test 3 failed: Expected 0 for non-empty, got {dut.all_empty.value}"
    print("Test 3 passed: Non-empty element at last position detected")
    
    # Test 4: Mix of empty and non-empty
    dut.dicts[0] = 0
    dut.dicts[1] = 0
    dut.dicts[2] = 42
    dut.dicts[3] = 0
    dut.dicts[4] = 128
    dut.dicts[5] = 0
    dut.dicts[6] = 0
    dut.dicts[7] = 0
    await Timer(1, units='ns')
    assert dut.all_empty.value == 0, f"Test 4 failed: Expected 0 for mixed, got {dut.all_empty.value}"
    print("Test 4 passed: Mixed empty/non-empty detected")
    
    # Test 5: All elements are 0xFF (max non-empty)
    for i in range(8):
        dut.dicts[i] = 255
    await Timer(1, units='ns')
    assert dut.all_empty.value == 0, f"Test 5 failed: Expected 0 for all non-empty, got {dut.all_empty.value}"
    print("Test 5 passed: All non-empty elements detected")
    
    # Test 6: Edge case - only one non-zero bit in one element
    dut.dicts[0] = 0
    dut.dicts[1] = 0
    dut.dicts[2] = 0
    dut.dicts[3] = 1  # Only bit 0 set
    dut.dicts[4] = 0
    dut.dicts[5] = 0
    dut.dicts[6] = 0
    dut.dicts[7] = 0
    await Timer(1, units='ns')
    assert dut.all_empty.value == 0, f"Test 6 failed: Expected 0 for single bit set, got {dut.all_empty.value}"
    print("Test 6 passed: Single bit non-zero detected")
    
    print("
=== Summary ===")
    print("6/6 tests passed")