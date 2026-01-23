import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_make_a_pile(dut):
    """Test the make_a_pile module with various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=3 (odd) -> [3, 5, 7]
    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = [3, 5, 7]
    for i, val in enumerate(expected):
        await RisingEdge(dut.clk)
        if dut.result_valid.value != 1:
            raise TestFailure(f"Test 1: result_valid should be 1 at cycle {i+1}")
        if dut.result_data.value != val:
            raise TestFailure(f"Test 1: Expected {val}, got {dut.result_data.value}")
        if dut.result_index.value != i+1:
            raise TestFailure(f"Test 1: Expected index {i+1}, got {dut.result_index.value}")
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Test 1: done should be 1 after n cycles")
    
    # Wait for idle
    await RisingEdge(dut.clk)
    
    # Test case 2: n=4 (even) -> [4, 6, 8, 10]
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = [4, 6, 8, 10]
    for i, val in enumerate(expected):
        await RisingEdge(dut.clk)
        if dut.result_valid.value != 1:
            raise TestFailure(f"Test 2: result_valid should be 1 at cycle {i+1}")
        if dut.result_data.value != val:
            raise TestFailure(f"Test 2: Expected {val}, got {dut.result_data.value}")
        if dut.result_index.value != i+1:
            raise TestFailure(f"Test 2: Expected index {i+1}, got {dut.result_index.value}")
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Test 2: done should be 1 after n cycles")
    
    # Wait for idle
    await RisingEdge(dut.clk)
    
    # Test case 3: n=5 -> [5, 7, 9, 11, 13]
    dut.n.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = [5, 7, 9, 11, 13]
    for i, val in enumerate(expected):
        await RisingEdge(dut.clk)
        if dut.result_valid.value != 1:
            raise TestFailure(f"Test 3: result_valid should be 1 at cycle {i+1}")
        if dut.result_data.value != val:
            raise TestFailure(f"Test 3: Expected {val}, got {dut.result_data.value}")
        if dut.result_index.value != i+1:
            raise TestFailure(f"Test 3: Expected index {i+1}, got {dut.result_index.value}")
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Test 3: done should be 1 after n cycles")
    
    # Wait for idle
    await RisingEdge(dut.clk)
    
    # Test case 4: n=6 -> [6, 8, 10, 12, 14, 16]
    dut.n.value = 6
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = [6, 8, 10, 12, 14, 16]
    for i, val in enumerate(expected):
        await RisingEdge(dut.clk)
        if dut.result_valid.value != 1:
            raise TestFailure(f"Test 4: result_valid should be 1 at cycle {i+1}")
        if dut.result_data.value != val:
            raise TestFailure(f"Test 4: Expected {val}, got {dut.result_data.value}")
        if dut.result_index.value != i+1:
            raise TestFailure(f"Test 4: Expected index {i+1}, got {dut.result_index.value}")
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Test 4: done should be 1 after n cycles")
    
    # Wait for idle
    await RisingEdge(dut.clk)
    
    # Test case 5: n=8 -> [8, 10, 12, 14, 16, 18, 20, 22]
    dut.n.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = [8, 10, 12, 14, 16, 18, 20, 22]
    for i, val in enumerate(expected):
        await RisingEdge(dut.clk)
        if dut.result_valid.value != 1:
            raise TestFailure(f"Test 5: result_valid should be 1 at cycle {i+1}")
        if dut.result_data.value != val:
            raise TestFailure(f"Test 5: Expected {val}, got {dut.result_data.value}")
        if dut.result_index.value != i+1:
            raise TestFailure(f"Test 5: Expected index {i+1}, got {dut.result_index.value}")
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Test 5: done should be 1 after n cycles")
    
    print("All tests passed!")
