import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def int_to_bytes(value):
    """Convert integer to list of 8 bytes for test input"""
    return [(value >> (8*i)) & 0xFF for i in range(8)]

@cocotb.test()
async def test_all_unique(dut):
    """Test check_unique module with various test cases"""
    
    # Test Case 1: All unique [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
    dut.data_0.value = 0x01
    dut.data_1.value = 0x02
    dut.data_2.value = 0x03
    dut.data_3.value = 0x04
    dut.data_4.value = 0x05
    dut.data_5.value = 0x06
    dut.data_6.value = 0x07
    dut.data_7.value = 0x08
    await Timer(1, units='ns')
    if dut.unique.value != 1:
        raise TestFailure(f"Test 1 failed: Expected unique=1 for all unique values, got {dut.unique.value}")
    print("Test 1 passed: All unique values (0x01-0x08) correctly detected")
    
    # Test Case 2: Has duplicate [0x01, 0x02, 0x01, 0x04, 0x05, 0x06, 0x07, 0x08]
    dut.data_0.value = 0x01
    dut.data_1.value = 0x02
    dut.data_2.value = 0x01
    dut.data_3.value = 0x04
    dut.data_4.value = 0x05
    dut.data_5.value = 0x06
    dut.data_6.value = 0x07
    dut.data_7.value = 0x08
    await Timer(1, units='ns')
    if dut.unique.value != 0:
        raise TestFailure(f"Test 2 failed: Expected unique=0 for duplicate 0x01, got {dut.unique.value}")
    print("Test 2 passed: Duplicate 0x01 correctly detected")
    
    # Test Case 3: All unique [0x0A, 0x14, 0x1E, 0x28, 0x32, 0x3C, 0x46, 0x50]
    dut.data_0.value = 0x0A
    dut.data_1.value = 0x14
    dut.data_2.value = 0x1E
    dut.data_3.value = 0x28
    dut.data_4.value = 0x32
    dut.data_5.value = 0x3C
    dut.data_6.value = 0x46
    dut.data_7.value = 0x50
    await Timer(1, units='ns')
    if dut.unique.value != 1:
        raise TestFailure(f"Test 3 failed: Expected unique=1 for all unique values, got {dut.unique.value}")
    print("Test 3 passed: All unique values (0x0A, 0x14, ...) correctly detected")
    
    # Test Case 4: Duplicate at end [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x01]
    dut.data_0.value = 0x01
    dut.data_1.value = 0x02
    dut.data_2.value = 0x03
    dut.data_3.value = 0x04
    dut.data_4.value = 0x05
    dut.data_5.value = 0x06
    dut.data_6.value = 0x07
    dut.data_7.value = 0x01
    await Timer(1, units='ns')
    if dut.unique.value != 0:
        raise TestFailure(f"Test 4 failed: Expected unique=0 for duplicate 0x01, got {dut.unique.value}")
    print("Test 4 passed: Duplicate 0x01 at position 7 correctly detected")
    
    # Test Case 5: All same [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    dut.data_0.value = 0xFF
    dut.data_1.value = 0xFF
    dut.data_2.value = 0xFF
    dut.data_3.value = 0xFF
    dut.data_4.value = 0xFF
    dut.data_5.value = 0xFF
    dut.data_6.value = 0xFF
    dut.data_7.value = 0xFF
    await Timer(1, units='ns')
    if dut.unique.value != 0:
        raise TestFailure(f"Test 5 failed: Expected unique=0 for all identical values, got {dut.unique.value}")
    print("Test 5 passed: All identical values (0xFF) correctly detected as non-unique")
    
    # Test Case 6: Zero values with duplicate [0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
    dut.data_0.value = 0x00
    dut.data_1.value = 0x00
    dut.data_2.value = 0x01
    dut.data_3.value = 0x02
    dut.data_4.value = 0x03
    dut.data_5.value = 0x04
    dut.data_6.value = 0x05
    dut.data_7.value = 0x06
    await Timer(1, units='ns')
    if dut.unique.value != 0:
        raise TestFailure(f"Test 6 failed: Expected unique=0 for duplicate 0x00, got {dut.unique.value}")
    print("Test 6 passed: Duplicate zeros correctly detected")
    
    # Test Case 7: Boundary values [0x00, 0x01, 0x02, 0x03, 0xFD, 0xFE, 0xFF, 0x7F]
    dut.data_0.value = 0x00
    dut.data_1.value = 0x01
    dut.data_2.value = 0x02
    dut.data_3.value = 0x03
    dut.data_4.value = 0xFD
    dut.data_5.value = 0xFE
    dut.data_6.value = 0xFF
    dut.data_7.value = 0x7F
    await Timer(1, units='ns')
    if dut.unique.value != 1:
        raise TestFailure(f"Test 7 failed: Expected unique=1 for boundary values, got {dut.unique.value}")
    print("Test 7 passed: Boundary values (0x00, 0x01, 0x02, 0x03, 0xFD, 0xFE, 0xFF, 0x7F) correctly detected")
    
    print("
=== Summary: All 7 tests passed ===")