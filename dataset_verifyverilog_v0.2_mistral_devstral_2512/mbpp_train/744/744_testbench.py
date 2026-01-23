import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_check_none(dut):
    """Test the check_none module with various inputs."""
    
    # Helper to set inputs
    def set_inputs(values):
        dut.data_0.value = values[0]
        dut.data_1.value = values[1]
        dut.data_2.value = values[2]
        dut.data_3.value = values[3]
        dut.data_4.value = values[4]
    
    # Test 1: Contains None (0xF) at position 4
    # Python: (10, 4, 5, 6, None) -> 0xA, 0x4, 0x5, 0x6, 0xF
    set_inputs([0xA, 0x4, 0x5, 0x6, 0xF])
    await Timer(1, units='ns')
    assert dut.has_none.value == 1, "Test 1 Failed: Expected 1 for (10, 4, 5, 6, None)"
    
    # Test 2: No None
    # Python: (7, 8, 9, 11, 14) -> 0x7, 0x8, 0x9, 0xB, 0xE
    set_inputs([0x7, 0x8, 0x9, 0xB, 0xE])
    await Timer(1, units='ns')
    assert dut.has_none.value == 0, "Test 2 Failed: Expected 0 for (7, 8, 9, 11, 14)"
    
    # Test 3: Contains None at position 4
    # Python: (1, 2, 3, 4, None) -> 0x1, 0x2, 0x3, 0x4, 0xF
    set_inputs([0x1, 0x2, 0x3, 0x4, 0xF])
    await Timer(1, units='ns')
    assert dut.has_none.value == 1, "Test 3 Failed: Expected 1 for (1, 2, 3, 4, None)"
    
    # Test 4: None at beginning
    set_inputs([0xF, 0x1, 0x2, 0x3, 0x4])
    await Timer(1, units='ns')
    assert dut.has_none.value == 1, "Test 4 Failed: Expected 1"
    
    # Test 5: None in middle
    set_inputs([0x1, 0x2, 0xF, 0x3, 0x4])
    await Timer(1, units='ns')
    assert dut.has_none.value == 1, "Test 5 Failed: Expected 1"

    print(f"Tests passed: 5/5")