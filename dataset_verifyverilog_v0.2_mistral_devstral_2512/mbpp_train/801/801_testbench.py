import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_three_equal_counter(dut):
    """Test the three_equal_counter module"""
    
    # Test 1: All three equal
    dut.x.value = 1
    dut.y.value = 1
    dut.z.value = 1
    await Timer(10, units='ns')
    assert dut.count.value == 3, f"Test 1 failed: Expected 3, got {dut.count.value}"
    
    # Test 2: All three distinct
    dut.x.value = -1
    dut.y.value = -2
    dut.z.value = -3
    await Timer(10, units='ns')
    assert dut.count.value == 0, f"Test 2 failed: Expected 0, got {dut.count.value}"
    
    # Test 3: Two equal (y and z)
    dut.x.value = 1
    dut.y.value = 2
    dut.z.value = 2
    await Timer(10, units='ns')
    assert dut.count.value == 2, f"Test 3 failed: Expected 2, got {dut.count.value}"
    
    # Test 4: Two equal (x and y)
    dut.x.value = 5
    dut.y.value = 5
    dut.z.value = 3
    await Timer(10, units='ns')
    assert dut.count.value == 2, f"Test 4 failed: Expected 2, got {dut.count.value}"
    
    # Test 5: Two equal (x and z)
    dut.x.value = 7
    dut.y.value = 9
    dut.z.value = 7
    await Timer(10, units='ns')
    assert dut.count.value == 2, f"Test 5 failed: Expected 2, got {dut.count.value}"
    
    print(f"Tests completed: 5/5 passed")