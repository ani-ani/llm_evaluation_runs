import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_sum_product(dut):
    """Test sum_product module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.array_len.value = 0
    for i in range(16):
        dut.array_data[i].value = 0
    
    # Reset
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def run_test(array_data, expected_sum, expected_product, test_name):
        """Helper function to run a single test case"""
        dut._log.info(f"Running test: {test_name}")
        
        # Set array data
        dut.array_len.value = len(array_data)
        for i, val in enumerate(array_data):
            dut.array_data[i].value = val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"{test_name}: Timeout waiting for done")
        
        # Check results
        actual_sum = int(dut.sum_out.value)
        actual_product = int(dut.product_out.value)
        
        dut._log.info(f"Expected: sum={expected_sum}, product={expected_product}")
        dut._log.info(f"Got: sum={actual_sum}, product={actual_product}")
        
        if actual_sum != expected_sum:
            raise TestFailure(f"{test_name}: Sum mismatch. Expected {expected_sum}, got {actual_sum}")
        if actual_product != expected_product:
            raise TestFailure(f"{test_name}: Product mismatch. Expected {expected_product}, got {actual_product}")
        
        dut._log.info(f"{test_name}: PASSED")
        
        # Wait one more cycle before next test
        await RisingEdge(dut.clk)
    
    # Test 1: Empty list
    await run_test([], 0, 1, "Empty list")
    
    # Test 2: Single element [10]
    await run_test([10], 10, 10, "Single element [10]")
    
    # Test 3: All ones [1, 1, 1]
    await run_test([1, 1, 1], 3, 1, "All ones [1,1,1]")
    
    # Test 4: With zero [100, 0]
    await run_test([100, 0], 100, 0, "With zero [100,0]")
    
    # Test 5: Various numbers [3, 5, 7]
    await run_test([3, 5, 7], 15, 105, "Various [3,5,7]")
    
    # Test 6: Larger list [1, 2, 3, 4]
    await run_test([1, 2, 3, 4], 10, 24, "Larger list [1,2,3,4]")
    
    dut._log.info("
=== Summary: All 6 tests passed! ===")