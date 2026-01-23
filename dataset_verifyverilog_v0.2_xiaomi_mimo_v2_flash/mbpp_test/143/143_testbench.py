import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_find_lists(dut):
    """Test finding number of lists in a tuple"""
    
    # Test Case 1: 2 valid lists
    dut.list_valid.value = 0b11  # Binary for 2 lists
    await Timer(10, units='ns')
    assert dut.num_lists_out.value == 2, f"Expected 2, got {dut.num_lists_out.value}"
    
    # Test Case 2: 3 valid lists
    dut.list_valid.value = 0b111  # Binary for 3 lists
    await Timer(10, units='ns')
    assert dut.num_lists_out.value == 3, f"Expected 3, got {dut.num_lists_out.value}"
    
    # Test Case 3: 1 valid list (padded with zeros in larger bus)
    dut.list_valid.value = 0b001  # Binary for 1 list
    await Timer(10, units='ns')
    assert dut.num_lists_out.value == 1, f"Expected 1, got {dut.num_lists_out.value}"
    
    # Test Case 4: Empty tuple (0 lists)
    dut.list_valid.value = 0b000
    await Timer(10, units='ns')
    assert dut.num_lists_out.value == 0, f"Expected 0, got {dut.num_lists_out.value}"

    print("All tests passed successfully")