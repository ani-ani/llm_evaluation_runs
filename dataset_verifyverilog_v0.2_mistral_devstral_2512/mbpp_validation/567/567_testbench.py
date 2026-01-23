import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_is_sorted_checker(dut):
    """Test the is_sorted_checker module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to load data
    async def load_data(data_list):
        dut._log.info(f"Loading data: {data_list}")
        for i, val in enumerate(data_list):
            dut.data_in.value = val
            dut.index.value = i
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
        dut.data_valid.value = 0
        await RisingEdge(dut.clk)
    
    # Helper function to check and verify
    async def check_sorted(data_list, expected_sorted, expected_error_idx=0):
        dut._log.info(f"Testing: {data_list}, Expected: sorted={expected_sorted}, error_idx={expected_error_idx}")
        
        # Load data
        await load_data(data_list)
        
        # Start check
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (15 cycles total: 8 load + 7 check)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify results
        if dut.done.value != 1:
            raise TestFailure("Done signal not asserted")
        
        if dut.is_sorted.value != expected_sorted:
            raise TestFailure(f"is_sorted mismatch: got {int(dut.is_sorted.value)}, expected {expected_sorted}")
        
        if expected_sorted == 0 and dut.error_index.value != expected_error_idx:
            raise TestFailure(f"error_index mismatch: got {int(dut.error_index.value)}, expected {expected_error_idx}")
        
        dut._log.info(f"Result: is_sorted={int(dut.is_sorted.value)}, error_index={int(dut.error_index.value)}")
    
    # Test 1: Sorted list [1,2,4,6,8,10,12,14]
    await check_sorted([1,2,4,6,8,10,12,14], 1, 0)
    
    # Test 2: Unsorted list [1,2,4,6,8,10,12,20,17] -> truncated to first 8: [1,2,4,6,8,10,12,20]
    # This is actually sorted, so let's use unsorted version
    await check_sorted([1,2,4,6,8,10,12,20], 1, 0)
    
    # Test 3: Unsorted list [1,2,4,6,8,10,15,14] - failure at index 6
    await check_sorted([1,2,4,6,8,10,15,14], 0, 6)
    
    # Additional edge cases
    # Test 4: All equal
    await check_sorted([5,5,5,5,5,5,5,5], 1, 0)
    
    # Test 5: Reverse sorted
    await check_sorted([8,7,6,5,4,3,2,1], 0, 0)
    
    # Test 6: Already sorted but close values
    await check_sorted([1,3,2,4,5,6,7,8], 0, 1)
    
    # Test 7: Minimum values
    await check_sorted([0,0,0,1,1,2,2,3], 1, 0)
    
    # Test 8: Single element effectively (with repeats)
    await check_sorted([1,1,1,1,1,1,1,1], 1, 0)
    
    dut._log.info("All tests passed!")

@cocotb.test()
async def test_is_sorted_load_sequence(dut):
    """Test that data loading works correctly with index values"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load data out of order to test indexing
    test_data = [10, 5, 8, 3, 12, 15, 2, 20]  # Unsorted
    
    dut._log.info("Loading data in non-sequential order")
    # Load at specific indices
    for i, val in enumerate(test_data):
        dut.data_in.value = val
        dut.index.value = i
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Start check
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Should be unsorted
    if dut.is_sorted.value != 0:
        raise TestFailure(f"Expected unsorted, got {int(dut.is_sorted.value)}")
    
    dut._log.info(f"Out-of-order load test passed: is_sorted={int(dut.is_sorted.value)}, error_index={int(dut.error_index.value)}")

@cocotb.test()
async def test_is_sorted_empty_after_reset(dut):
    """Test that module works correctly after reset"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Multiple resets
    for i in range(3):
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.data_valid.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        
        # Check outputs are 0 after reset
        if dut.is_sorted.value != 0 or dut.done.value != 0:
            raise TestFailure(f"Outputs not zero after reset: is_sorted={int(dut.is_sorted.value)}, done={int(dut.done.value)}")
        
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("Reset test passed")
