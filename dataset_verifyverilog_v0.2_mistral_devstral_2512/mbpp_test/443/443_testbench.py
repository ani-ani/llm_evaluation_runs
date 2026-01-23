import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_largest_neg(dut):
    """Test largest_neg module with various test cases"""
    
    # Test case 1: [1,2,3,-4,-6] -> -6
    dut.list1_0.value = 1
    dut.list1_1.value = 2
    dut.list1_2.value = 3
    dut.list1_3.value = -4 & 0xFF  # Two's complement
    dut.list1_4.value = -6 & 0xFF  # Two's complement
    dut.list1_5.value = 0
    dut.list1_6.value = 0
    dut.list1_7.value = 0
    dut.valid_count.value = 5
    await Timer(1, units='ns')
    
    result = dut.result.value
    found = dut.found.value
    if found != 1:
        raise TestFailure(f"Test 1: Expected found=1, got {found}")
    if result != ( -6 & 0xFF):
        raise TestFailure(f"Test 1: Expected -6 (0x{(-6 & 0xFF):02X}), got 0x{result:02X}")
    print(f"Test 1 passed: largest negative in [1,2,3,-4,-6] is -6")
    
    # Test case 2: [1,2,3,-8,-9] -> -9
    dut.list1_0.value = 1
    dut.list1_1.value = 2
    dut.list1_2.value = 3
    dut.list1_3.value = -8 & 0xFF
    dut.list1_4.value = -9 & 0xFF
    dut.list1_5.value = 0
    dut.list1_6.value = 0
    dut.list1_7.value = 0
    dut.valid_count.value = 5
    await Timer(1, units='ns')
    
    result = dut.result.value
    found = dut.found.value
    if found != 1:
        raise TestFailure(f"Test 2: Expected found=1, got {found}")
    if result != ( -9 & 0xFF):
        raise TestFailure(f"Test 2: Expected -9 (0x{(-9 & 0xFF):02X}), got 0x{result:02X}")
    print(f"Test 2 passed: largest negative in [1,2,3,-8,-9] is -9")
    
    # Test case 3: [1,2,3,4,-1] -> -1
    dut.list1_0.value = 1
    dut.list1_1.value = 2
    dut.list1_2.value = 3
    dut.list1_3.value = 4
    dut.list1_4.value = -1 & 0xFF
    dut.list1_5.value = 0
    dut.list1_6.value = 0
    dut.list1_7.value = 0
    dut.valid_count.value = 5
    await Timer(1, units='ns')
    
    result = dut.result.value
    found = dut.found.value
    if found != 1:
        raise TestFailure(f"Test 3: Expected found=1, got {found}")
    if result != ( -1 & 0xFF):
        raise TestFailure(f"Test 3: Expected -1 (0x{(-1 & 0xFF):02X}), got 0x{result:02X}")
    print(f"Test 3 passed: largest negative in [1,2,3,4,-1] is -1")
    
    # Test case 4: [5,10,15,20] (no negatives) -> found=0
    dut.list1_0.value = 5
    dut.list1_1.value = 10
    dut.list1_2.value = 15
    dut.list1_3.value = 20
    dut.list1_4.value = 0
    dut.list1_5.value = 0
    dut.list1_6.value = 0
    dut.list1_7.value = 0
    dut.valid_count.value = 4
    await Timer(1, units='ns')
    
    result = dut.result.value
    found = dut.found.value
    if found != 0:
        raise TestFailure(f"Test 4: Expected found=0 (no negatives), got {found}")
    print(f"Test 4 passed: no negatives in [5,10,15,20], found=0")
    
    # Test case 5: [-10, -5, -3] -> -3 (closest to zero)
    dut.list1_0.value = -10 & 0xFF
    dut.list1_1.value = -5 & 0xFF
    dut.list1_2.value = -3 & 0xFF
    dut.list1_3.value = 0
    dut.list1_4.value = 0
    dut.list1_5.value = 0
    dut.list1_6.value = 0
    dut.list1_7.value = 0
    dut.valid_count.value = 3
    await Timer(1, units='ns')
    
    result = dut.result.value
    found = dut.found.value
    if found != 1:
        raise TestFailure(f"Test 5: Expected found=1, got {found}")
    if result != ( -3 & 0xFF):
        raise TestFailure(f"Test 5: Expected -3 (0x{(-3 & 0xFF):02X}), got 0x{result:02X}")
    print(f"Test 5 passed: largest negative in [-10,-5,-3] is -3")
    
    print("
=== All 5/5 tests passed ===")
