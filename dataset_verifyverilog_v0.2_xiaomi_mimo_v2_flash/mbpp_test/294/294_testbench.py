import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_val_heterogeneous(dut):
    """Test max_val_heterogeneous module with heterogeneous data"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    for i in range(8):
        dut.array_data[i].value = 0
    
    # Reset
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: ['Python', 3, 2, 4, 5, 'version'] -> max=5
    # Adapted: [0x00, 0x03, 0x02, 0x04, 0x05, 0x00] (6 elements)
    dut.num_elements.value = 6
    dut.array_data[0].value = 0x00  # string
    dut.array_data[1].value = 0x03  # int 3
    dut.array_data[2].value = 0x02  # int 2
    dut.array_data[3].value = 0x04  # int 4
    dut.array_data[4].value = 0x05  # int 5
    dut.array_data[5].value = 0x00  # string
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (9 cycles: 1 SCAN + 7 updates + DONE)
    for _ in range(9):
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Test 1: done signal not asserted")
    if not dut.valid.value:
        raise TestFailure("Test 1: valid signal not asserted")
    if dut.max_int_result.value != 5:
        raise TestFailure(f"Test 1: Expected 5, got {int(dut.max_int_result.value)}")
    print("Test 1 passed")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: ['Python', 15, 20, 25] -> max=25
    # Adapted: [0x00, 0x0F, 0x14, 0x19] (4 elements)
    dut.num_elements.value = 4
    dut.array_data[0].value = 0x00  # string
    dut.array_data[1].value = 0x0F  # int 15
    dut.array_data[2].value = 0x14  # int 20
    dut.array_data[3].value = 0x19  # int 25
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(9):
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Test 2: done signal not asserted")
    if not dut.valid.value:
        raise TestFailure("Test 2: valid signal not asserted")
    if dut.max_int_result.value != 0x19:
        raise TestFailure(f"Test 2: Expected 25 (0x19), got {int(dut.max_int_result.value)}")
    print("Test 2 passed")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: ['Python', 30, 20, 40, 50, 'version'] -> max=50
    # Adapted: [0x00, 0x1E, 0x14, 0x28, 0x32, 0x00] (6 elements)
    dut.num_elements.value = 6
    dut.array_data[0].value = 0x00  # string
    dut.array_data[1].value = 0x1E  # int 30
    dut.array_data[2].value = 0x14  # int 20
    dut.array_data[3].value = 0x28  # int 40
    dut.array_data[4].value = 0x32  # int 50
    dut.array_data[5].value = 0x00  # string
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(9):
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Test 3: done signal not asserted")
    if not dut.valid.value:
        raise TestFailure("Test 3: valid signal not asserted")
    if dut.max_int_result.value != 0x32:
        raise TestFailure(f"Test 3: Expected 50 (0x32), got {int(dut.max_int_result.value)}")
    print("Test 3 passed")
    
    # Reset for edge case test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 4: All strings -> invalid result
    # Adapted: [0x00, 0x00, 0x00] (3 elements)
    dut.num_elements.value = 3
    dut.array_data[0].value = 0x00
    dut.array_data[1].value = 0x00
    dut.array_data[2].value = 0x00
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(9):
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Test 4: done signal not asserted")
    if dut.valid.value:
        raise TestFailure("Test 4: valid should be 0 for all strings")
    if dut.max_int_result.value != 0:
        raise TestFailure(f"Test 4: Expected 0, got {int(dut.max_int_result.value)}")
    print("Test 4 passed")
    
    # Reset for edge case test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 5: Single integer
    # Adapted: [0x2A] (1 element, value 42)
    dut.num_elements.value = 1
    dut.array_data[0].value = 0x2A  # int 42
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(9):
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Test 5: done signal not asserted")
    if not dut.valid.value:
        raise TestFailure("Test 5: valid signal not asserted")
    if dut.max_int_result.value != 0x2A:
        raise TestFailure(f"Test 5: Expected 42 (0x2A), got {int(dut.max_int_result.value)}")
    print("Test 5 passed")
    
    print("All 5 tests passed successfully")
