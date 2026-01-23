import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess

@cocotb.test()
async def test_swap_list_basic(dut):
    """Test basic swap functionality with test case 1"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [12, 35, 9, 56, 24] -> [24, 35, 9, 56, 12]
    dut.data_in.value = [12, 35, 9, 56, 24]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    # Check done signal
    if not dut.done.value:
        raise TestFailure("Done signal not asserted after one cycle")
    
    # Verify output
    expected = [24, 35, 9, 56, 12]
    actual = [int(dut.data_out.value[i]) for i in range(5)]
    
    if actual != expected:
        raise TestFailure(f"Test 1 failed: Expected {expected}, got {actual}")
    
    print(f"Test 1 passed: {actual}")
    
    # Wait for start to go low
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.done.value:
        raise TestFailure("Done signal still high after start went low")

@cocotb.test()
async def test_swap_list_small(dut):
    """Test with smaller values - test case 2 (adapted to 5 elements)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2 adapted: [1, 2, 3, 0, 0] -> [3, 2, 1, 0, 0]
    # Original [1,2,3] padded to 5 elements
    dut.data_in.value = [1, 2, 3, 0, 0]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Done signal not asserted")
    
    expected = [3, 2, 1, 0, 0]
    actual = [int(dut.data_out.value[i]) for i in range(5)]
    
    if actual != expected:
        raise TestFailure(f"Test 2 failed: Expected {expected}, got {actual}")
    
    print(f"Test 2 passed: {actual}")
    
    dut.start.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_swap_list_nochange(dut):
    """Test when first and last are same (edge case)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: [5, 2, 3, 4, 5] -> [5, 2, 3, 4, 5] (first=last)
    dut.data_in.value = [5, 2, 3, 4, 5]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Done signal not asserted")
    
    expected = [5, 2, 3, 4, 5]
    actual = [int(dut.data_out.value[i]) for i in range(5)]
    
    if actual != expected:
        raise TestFailure(f"Test 3 failed: Expected {expected}, got {actual}")
    
    print(f"Test 3 passed: {actual}")
    
    dut.start.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_swap_list_max_values(dut):
    """Test with maximum 8-bit values"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Max values test: [255, 128, 64, 32, 1] -> [1, 128, 64, 32, 255]
    dut.data_in.value = [255, 128, 64, 32, 1]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Done signal not asserted")
    
    expected = [1, 128, 64, 32, 255]
    actual = [int(dut.data_out.value[i]) for i in range(5)]
    
    if actual != expected:
        raise TestFailure(f"Test 4 failed: Expected {expected}, got {actual}")
    
    print(f"Test 4 passed: {actual}")
    
    dut.start.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_swap_list_all_same(dut):
    """Test with all elements same"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # All same: [10, 10, 10, 10, 10] -> [10, 10, 10, 10, 10]
    dut.data_in.value = [10, 10, 10, 10, 10]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Done signal not asserted")
    
    expected = [10, 10, 10, 10, 10]
    actual = [int(dut.data_out.value[i]) for i in range(5)]
    
    if actual != expected:
        raise TestFailure(f"Test 5 failed: Expected {expected}, got {actual}")
    
    print(f"Test 5 passed: {actual}")
    print("
All 5 tests passed successfully!")
    
    dut.start.value = 0
    await RisingEdge(dut.clk)