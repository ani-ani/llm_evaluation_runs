import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_check_same_type(dut):
    """Test that all identical elements return True, mixed elements return False"""
    
    # Test 1: All same type (all integers represented as 0x01)
    dut.data_array[0] = 0x01
    dut.data_array[1] = 0x01
    dut.data_array[2] = 0x01
    dut.data_array[3] = 0x01
    dut.data_array[4] = 0x01
    dut.data_array[5] = 0x01
    dut.data_array[6] = 0x01
    dut.data_array[7] = 0x01
    await Timer(1, units='ns')
    assert dut.result.value == 1, "Test 1 failed: All identical should return 1"
    print("Test 1 passed: All same type (0x01)")
    
    # Test 2: Mixed types (integers and strings)
    dut.data_array[0] = 0x01  # integer
    dut.data_array[1] = 0x01  # integer
    dut.data_array[2] = 0x02  # string
    dut.data_array[3] = 0x01  # integer
    dut.data_array[4] = 0x01  # integer
    dut.data_array[5] = 0x01  # integer
    dut.data_array[6] = 0x01  # integer
    dut.data_array[7] = 0x01  # integer
    await Timer(1, units='ns')
    assert dut.result.value == 0, "Test 2 failed: Mixed types should return 0"
    print("Test 2 passed: Mixed types (0x01, 0x02, 0x01...)")
    
    # Test 3: All same type (all integers, different value)
    dut.data_array[0] = 0xFF
    dut.data_array[1] = 0xFF
    dut.data_array[2] = 0xFF
    dut.data_array[3] = 0xFF
    dut.data_array[4] = 0xFF
    dut.data_array[5] = 0xFF
    dut.data_array[6] = 0xFF
    dut.data_array[7] = 0xFF
    await Timer(1, units='ns')
    assert dut.result.value == 1, "Test 3 failed: All identical should return 1"
    print("Test 3 passed: All same type (0xFF)")
    
    # Test 4: All different types
    dut.data_array[0] = 0x01
    dut.data_array[1] = 0x02
    dut.data_array[2] = 0x03
    dut.data_array[3] = 0x04
    dut.data_array[4] = 0x05
    dut.data_array[5] = 0x06
    dut.data_array[6] = 0x07
    dut.data_array[7] = 0x08
    await Timer(1, units='ns')
    assert dut.result.value == 0, "Test 4 failed: All different should return 0"
    print("Test 4 passed: All different types")
    
    # Test 5: First element different from rest
    dut.data_array[0] = 0x05
    dut.data_array[1] = 0x01
    dut.data_array[2] = 0x01
    dut.data_array[3] = 0x01
    dut.data_array[4] = 0x01
    dut.data_array[5] = 0x01
    dut.data_array[6] = 0x01
    dut.data_array[7] = 0x01
    await Timer(1, units='ns')
    assert dut.result.value == 0, "Test 5 failed: First different should return 0"
    print("Test 5 passed: First element different")
    
    print("
5/5 tests passed")