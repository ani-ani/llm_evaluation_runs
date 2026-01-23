import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_pack_duplicates(dut):
    """Test packing consecutive duplicates"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.length.value = 0
    for i in range(16):
        dut.data_in[i].value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1
    dut._log.info("Running Test Case 1")
    input_data_1 = [0, 0, 1, 2, 3, 4, 4, 5, 6, 6, 6, 7, 8, 9, 4, 4]
    expected_groups_1 = [
        (0, 2), (2, 1), (3, 1), (4, 1), (5, 2), (6, 1), (7, 3), (8, 1), (9, 1), (10, 1), (11, 2)
    ]
    
    dut.length.value = len(input_data_1)
    for i, val in enumerate(input_data_1):
        dut.data_in[i].value = val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal not asserted in time"
    assert int(dut.num_groups.value) == len(expected_groups_1), f"Expected {len(expected_groups_1)} groups, got {int(dut.num_groups.value)}"
    
    for i in range(len(expected_groups_1)):
        start = int(dut.group_starts[i].value)
        length = int(dut.group_lengths[i].value)
        exp_start, exp_len = expected_groups_1[i]
        assert start == exp_start, f"Group {i}: Expected start {exp_start}, got {start}"
        assert length == exp_len, f"Group {i}: Expected length {exp_len}, got {length}"
    
    dut._log.info("Test Case 1 Passed")

    # Test Case 2
    dut._log.info("Running Test Case 2")
    input_data_2 = [10, 10, 15, 19, 18, 18, 17, 26, 26, 17, 18, 10]
    expected_groups_2 = [
        (0, 2), (2, 1), (3, 1), (4, 2), (6, 1), (7, 2), (9, 1), (10, 1), (11, 1)
    ]
    
    dut.length.value = len(input_data_2)
    for i in range(16):
        if i < len(input_data_2):
            dut.data_in[i].value = input_data_2[i]
        else:
            dut.data_in[i].value = 0
            
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        
    assert dut.done.value == 1
    assert int(dut.num_groups.value) == len(expected_groups_2)
    
    for i in range(len(expected_groups_2)):
        start = int(dut.group_starts[i].value)
        length = int(dut.group_lengths[i].value)
        exp_start, exp_len = expected_groups_2[i]
        assert start == exp_start and length == exp_len

    dut._log.info("Test Case 2 Passed")

    # Test Case 3 (Characters encoded as ASCII integers)
    dut._log.info("Running Test Case 3")
    input_data_3 = [ord('a'), ord('a'), ord('b'), ord('c'), ord('d'), ord('d')]
    expected_groups_3 = [
        (0, 2), (2, 1), (3, 1), (4, 2)
    ]
    
    dut.length.value = len(input_data_3)
    for i in range(16):
        if i < len(input_data_3):
            dut.data_in[i].value = input_data_3[i]
        else:
            dut.data_in[i].value = 0
            
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        
    assert dut.done.value == 1
    assert int(dut.num_groups.value) == len(expected_groups_3)
    
    for i in range(len(expected_groups_3)):
        start = int(dut.group_starts[i].value)
        length = int(dut.group_lengths[i].value)
        exp_start, exp_len = expected_groups_3[i]
        assert start == exp_start and length == exp_len

    dut._log.info("Test Case 3 Passed")
    
    dut._log.info("All 3/3 tests passed")