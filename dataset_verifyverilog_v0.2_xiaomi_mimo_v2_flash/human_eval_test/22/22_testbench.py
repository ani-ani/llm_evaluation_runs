import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_filter_integers(dut):
    """Test filter_integers module with various mixed-type inputs"""
    
    # Test case 1: Empty-like (all non-integers) -> expect count=0
    dut.data_array.value = 0  # All zeros means all type=0 with value=0
    await Timer(10, units='ns')
    if dut.count.value != 16:
        raise TestFailure(f"Test 1 failed: expected count=16, got {dut.count.value}")
    
    # Test case 2: Mixed types [int, non-int, int] -> should extract integers
    # data_array[0]: type=0, value=10 (0x00000A)
    # data_array[1]: type=1, value=20 (0x010014) -> filtered
    # data_array[2]: type=0, value=30 (0x00001E)
    # Rest: type=1
    dut.data_array.value = 0
    dut.data_array[0].value = 0x00000A  # type=0, value=10
    dut.data_array[1].value = 0x010014  # type=1, value=20
    dut.data_array[2].value = 0x00001E  # type=0, value=30
    dut.data_array[3].value = 0x020005  # type=2, value=5
    dut.data_array[4].value = 0x0000FF  # type=0, value=255
    await Timer(10, units='ns')
    
    expected_count = 3
    if dut.count.value != expected_count:
        raise TestFailure(f"Test 2 failed: expected count={expected_count}, got {dut.count.value}")
    
    expected_integers = [10, 30, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    for i in range(16):
        if dut.filtered_integers[i].value != expected_integers[i]:
            raise TestFailure(f"Test 2 failed at index {i}: expected {expected_integers[i]}, got {dut.filtered_integers[i].value}")
    
    # Test case 3: All integers [1, 2, 3, 3, 3] (some duplicates)
    dut.data_array.value = 0
    dut.data_array[0].value = 0x000001  # type=0, value=1
    dut.data_array[1].value = 0x000002  # type=0, value=2
    dut.data_array[2].value = 0x000003  # type=0, value=3
    dut.data_array[3].value = 0x000003  # type=0, value=3
    dut.data_array[4].value = 0x000003  # type=0, value=3
    for i in range(5, 16):
        dut.data_array[i].value = 0x010000  # non-integers
    await Timer(10, units='ns')
    
    expected_count = 5
    if dut.count.value != expected_count:
        raise TestFailure(f"Test 3 failed: expected count={expected_count}, got {dut.count.value}")
    
    expected_integers = [1, 2, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    for i in range(16):
        if dut.filtered_integers[i].value != expected_integers[i]:
            raise TestFailure(f"Test 3 failed at index {i}: expected {expected_integers[i]}, got {dut.filtered_integers[i].value}")
    
    # Test case 4: No integers
    dut.data_array.value = 0
    for i in range(16):
        dut.data_array[i].value = (i+1) << 8  # non-zero type, value irrelevant
    await Timer(10, units='ns')
    
    if dut.count.value != 0:
        raise TestFailure(f"Test 4 failed: expected count=0, got {dut.count.value}")
    
    # Test case 5: Single integer at end
    dut.data_array.value = 0
    for i in range(15):
        dut.data_array[i].value = 0x010000  # non-integer
    dut.data_array[15].value = 0x000042  # type=0, value=66
    await Timer(10, units='ns')
    
    if dut.count.value != 1:
        raise TestFailure(f"Test 5 failed: expected count=1, got {dut.count.value}")
    if dut.filtered_integers[0].value != 66:
        raise TestFailure(f"Test 5 failed: expected integer 66, got {dut.filtered_integers[0].value}")
    
    print("All 5 tests passed!")
