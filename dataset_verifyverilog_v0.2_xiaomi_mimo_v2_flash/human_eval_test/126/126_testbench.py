import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_is_sorted(dut):
    """Test is_sorted module with various arrays"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    dut.data_in.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to run test
    async def run_test(array, expected, test_name):
        dut._log.info(f"Testing {test_name}: {array}")
        
        # Start computation
        dut.start.value = 1
        dut.len.value = len(array)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed array elements sequentially
        for i, val in enumerate(array):
            dut.data_in.value = val
            await RisingEdge(dut.clk)
        
        # Wait for completion (max 9 cycles total)
        for _ in range(10):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        actual = int(dut.result.value)
        assert actual == expected, f"{test_name}: expected {expected}, got {actual}"
        dut._log.info(f"  Result: {actual} (expected {expected}) ✓")
    
    # Test cases from problem
    await run_test([5], 1, "single element")
    await run_test([1, 2, 3, 4, 5], 1, "strictly increasing")
    await run_test([1, 3, 2, 4, 5], 0, "out of order at position 2")
    await run_test([1, 2, 3, 4, 5, 6], 1, "six elements increasing")
    await run_test([1, 2, 3, 4, 5, 6, 7], 1, "seven elements increasing")
    await run_test([1, 3, 2, 4, 5, 6, 7], 0, "out of order at position 2")
    await run_test([], 1, "empty array")
    await run_test([1], 1, "single element 1")
    await run_test([3, 2, 1], 0, "descending")
    await run_test([1, 2, 2, 2, 3, 4], 0, "three duplicates")
    await run_test([1, 2, 3, 3, 3, 4], 0, "three duplicates")
    await run_test([1, 2, 2, 3, 3, 4], 1, "two duplicates OK")
    await run_test([1, 2, 3, 4], 1, "four elements increasing")
    
    # Additional edge cases
    await run_test([1, 1], 1, "two duplicates")
    await run_test([1, 1, 1], 0, "three duplicates")
    await run_test([2, 2, 3], 1, "duplicate at start")
    await run_test([1, 2, 3, 3], 1, "duplicate at end")
    await run_test([1, 1, 2, 2], 1, "pairs of duplicates")
    await run_test([1, 1, 1, 2], 0, "three duplicates at start")
    
    dut._log.info("All tests passed!")