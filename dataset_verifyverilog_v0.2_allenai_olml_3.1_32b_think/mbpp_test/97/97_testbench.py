import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_frequency_counter(dut):
    """Test frequency counter with 3x8 array"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.row_idx.value = 0
    for i in range(8):
        dut.data_in[i].value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [[1,2,3,2],[4,5,6,2],[7,8,9,5]]
    dut._log.info("Test Case 1: Row 0 [1,2,3,2]")
    row0 = [1, 2, 3, 2]
    for i in range(8):
        dut.data_in[i].value = row0[i] if i < len(row0) else 0
    dut.row_idx.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Process row 0
    for i in range(8):
        await RisingEdge(dut.clk)
    
    # Load row 1
    dut._log.info("Test Case 1: Row 1 [4,5,6,2]")
    row1 = [4, 5, 6, 2]
    for i in range(8):
        dut.data_in[i].value = row1[i] if i < len(row1) else 0
    dut.row_idx.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for i in range(8):
        await RisingEdge(dut.clk)
    
    # Load row 2
    dut._log.info("Test Case 1: Row 2 [7,8,9,5]")
    row2 = [7, 8, 9, 5]
    for i in range(8):
        dut.data_in[i].value = row2[i] if i < len(row2) else 0
    dut.row_idx.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for i in range(8):
        await RisingEdge(dut.clk)
    
    # Wait for done
    timeout = 50
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Verify frequencies
    expected = {1:1, 2:3, 3:1, 4:1, 5:2, 6:1, 7:1, 8:1, 9:1}
    for key, expected_freq in expected.items():
        dut.key_out.value = key
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
        # Wait for valid
        for _ in range(10):
            if dut.valid.value == 1:
                break
            await RisingEdge(dut.clk)
        actual = int(dut.freq_value.value)
        dut._log.info(f"Key {key}: expected {expected_freq}, got {actual}")
        if actual != expected_freq:
            raise TestFailure(f"Key {key}: expected {expected_freq}, got {actual}")
    
    # Test Case 2: All unique
    dut._log.info("
Test Case 2: All unique values")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Row 0
    row0 = [1, 2, 3, 4]
    for i in range(8):
        dut.data_in[i].value = row0[i] if i < len(row0) else 0
    dut.row_idx.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for i in range(8):
        await RisingEdge(dut.clk)
    
    # Row 1
    row1 = [5, 6, 7, 8]
    for i in range(8):
        dut.data_in[i].value = row1[i] if i < len(row1) else 0
    dut.row_idx.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for i in range(8):
        await RisingEdge(dut.clk)
    
    # Row 2
    row2 = [9, 10, 11, 12]
    for i in range(8):
        dut.data_in[i].value = row2[i] if i < len(row2) else 0
    dut.row_idx.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for i in range(8):
        await RisingEdge(dut.clk)
    
    # Wait for done
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    expected2 = {1:1, 2:1, 3:1, 4:1, 5:1, 6:1, 7:1, 8:1, 9:1, 10:1, 11:1, 12:1}
    for key, expected_freq in expected2.items():
        dut.key_out.value = key
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
        for _ in range(10):
            if dut.valid.value == 1:
                break
            await RisingEdge(dut.clk)
        actual = int(dut.freq_value.value)
        if actual != expected_freq:
            raise TestFailure(f"Key {key}: expected {expected_freq}, got {actual}")
    
    # Test Case 3: [[20,30,40,17],[18,16,14,13],[10,20,30,40]]
    dut._log.info("
Test Case 3")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Row 0
    row0 = [20, 30, 40, 17]
    for i in range(8):
        dut.data_in[i].value = row0[i] if i < len(row0) else 0
    dut.row_idx.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for i in range(8):
        await RisingEdge(dut.clk)
    
    # Row 1
    row1 = [18, 16, 14, 13]
    for i in range(8):
        dut.data_in[i].value = row1[i] if i < len(row1) else 0
    dut.row_idx.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for i in range(8):
        await RisingEdge(dut.clk)
    
    # Row 2
    row2 = [10, 20, 30, 40]
    for i in range(8):
        dut.data_in[i].value = row2[i] if i < len(row2) else 0
    dut.row_idx.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for i in range(8):
        await RisingEdge(dut.clk)
    
    # Wait for done
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    expected3 = {20:2, 30:2, 40:2, 17:1, 18:1, 16:1, 14:1, 13:1, 10:1}
    for key, expected_freq in expected3.items():
        dut.key_out.value = key
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
        for _ in range(10):
            if dut.valid.value == 1:
                break
            await RisingEdge(dut.clk)
        actual = int(dut.freq_value.value)
        if actual != expected_freq:
            raise TestFailure(f"Key {key}: expected {expected_freq}, got {actual}")
    
    dut._log.info("All tests passed!")