import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_pos_counter(dut):
    """Test counting non-negative numbers in a 4-element array"""
    
    # Test 1: [1, -2, 3, -4] -> should be 2
    dut.data_in_0.value = 1    # 0x01
    dut.data_in_1.value = -2   # 0xFE (two's complement)
    dut.data_in_2.value = 3    # 0x03
    dut.data_in_3.value = -4   # 0xFC
    await Timer(1, units='ns')
    result = int(dut.count.value)
    if result != 2:
        raise TestFailure(f"Test 1 failed: expected 2, got {result}")
    print(f"Test 1: [1, -2, 3, -4] -> count={result} ✓")
    
    # Test 2: [3, 4, 5, -1] -> should be 3
    dut.data_in_0.value = 3    # 0x03
    dut.data_in_1.value = 4    # 0x04
    dut.data_in_2.value = 5    # 0x05
    dut.data_in_3.value = -1   # 0xFF
    await Timer(1, units='ns')
    result = int(dut.count.value)
    if result != 3:
        raise TestFailure(f"Test 2 failed: expected 3, got {result}")
    print(f"Test 2: [3, 4, 5, -1] -> count={result} ✓")
    
    # Test 3: [1, 2, 3, 4] -> should be 4
    dut.data_in_0.value = 1    # 0x01
    dut.data_in_1.value = 2    # 0x02
    dut.data_in_2.value = 3    # 0x03
    dut.data_in_3.value = 4    # 0x04
    await Timer(1, units='ns')
    result = int(dut.count.value)
    if result != 4:
        raise TestFailure(f"Test 3 failed: expected 4, got {result}")
    print(f"Test 3: [1, 2, 3, 4] -> count={result} ✓")
    
    # Test 4: All negative [-1, -2, -3, -4] -> should be 0
    dut.data_in_0.value = -1   # 0xFF
    dut.data_in_1.value = -2   # 0xFE
    dut.data_in_2.value = -3   # 0xFD
    dut.data_in_3.value = -4   # 0xFC
    await Timer(1, units='ns')
    result = int(dut.count.value)
    if result != 0:
        raise TestFailure(f"Test 4 failed: expected 0, got {result}")
    print(f"Test 4: [-1, -2, -3, -4] -> count={result} ✓")
    
    # Test 5: Mixed with zeros [0, -1, 0, 2] -> should be 3 (zero is non-negative)
    dut.data_in_0.value = 0    # 0x00
    dut.data_in_1.value = -1   # 0xFF
    dut.data_in_2.value = 0    # 0x00
    dut.data_in_3.value = 2    # 0x02
    await Timer(1, units='ns')
    result = int(dut.count.value)
    if result != 3:
        raise TestFailure(f"Test 5 failed: expected 3, got {result}")
    print(f"Test 5: [0, -1, 0, 2] -> count={result} ✓")
    
    print("
All tests passed! 5/5")