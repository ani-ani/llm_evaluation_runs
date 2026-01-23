import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_find_first_missing(dut):
    """Test find_first_missing with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_size.value = 0
    for i in range(8):
        dut.array_data[i].value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [0,1,2,3] -> should return 4
    dut.array_size.value = 4
    dut.array_data[0].value = 0
    dut.array_data[1].value = 1
    dut.array_data[2].value = 2
    dut.array_data[3].value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(10):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Done signal not asserted")
    if dut.missing_number.value != 4:
        raise TestFailure(f"Test 1: Expected 4, got {int(dut.missing_number.value)}")
    print(f"Test 1 passed: [0,1,2,3] -> {int(dut.missing_number.value)}")
    
    await RisingEdge(dut.clk)
    
    # Test 2: [0,1,2,6,9] -> should return 3
    dut.array_size.value = 5
    dut.array_data[0].value = 0
    dut.array_data[1].value = 1
    dut.array_data[2].value = 2
    dut.array_data[3].value = 6
    dut.array_data[4].value = 9
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Done signal not asserted")
    if dut.missing_number.value != 3:
        raise TestFailure(f"Test 2: Expected 3, got {int(dut.missing_number.value)}")
    print(f"Test 2 passed: [0,1,2,6,9] -> {int(dut.missing_number.value)}")
    
    await RisingEdge(dut.clk)
    
    # Test 3: [2,3,5,8,9] -> should return 0
    dut.array_size.value = 5
    dut.array_data[0].value = 2
    dut.array_data[1].value = 3
    dut.array_data[2].value = 5
    dut.array_data[3].value = 8
    dut.array_data[4].value = 9
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: Done signal not asserted")
    if dut.missing_number.value != 0:
        raise TestFailure(f"Test 3: Expected 0, got {int(dut.missing_number.value)}")
    print(f"Test 3 passed: [2,3,5,8,9] -> {int(dut.missing_number.value)}")
    
    await RisingEdge(dut.clk)
    
    # Test 4: Empty array -> should return 0
    dut.array_size.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: Done signal not asserted")
    if dut.missing_number.value != 0:
        raise TestFailure(f"Test 4: Expected 0, got {int(dut.missing_number.value)}")
    print(f"Test 4 passed: [] -> {int(dut.missing_number.value)}")
    
    await RisingEdge(dut.clk)
    
    # Test 5: [0,1,3,4] -> should return 2
    dut.array_size.value = 4
    dut.array_data[0].value = 0
    dut.array_data[1].value = 1
    dut.array_data[2].value = 3
    dut.array_data[3].value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure("Test 5: Done signal not asserted")
    if dut.missing_number.value != 2:
        raise TestFailure(f"Test 5: Expected 2, got {int(dut.missing_number.value)}")
    print(f"Test 5 passed: [0,1,3,4] -> {int(dut.missing_number.value)}")
    
    print("
Summary: 5/5 tests passed")