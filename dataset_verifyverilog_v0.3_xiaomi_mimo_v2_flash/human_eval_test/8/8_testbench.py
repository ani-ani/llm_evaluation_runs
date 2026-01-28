import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sum_product(dut):
    """
    Test sum_product module with various test cases.
    """
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_in.value = 0
    dut.count.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_list, expected_sum, expected_product)
    test_cases = [
        ([], 0, 1),
        ([1, 1, 1], 3, 1),
        ([100, 0], 100, 0),
        ([3, 5, 7], 15, 105),
        ([10], 10, 10)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_list, expected_sum, expected_product) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: {input_list}")
        
        # Wait for IDLE state
        await RisingEdge(dut.clk)
        
        # Set start and count
        dut.count.value = len(input_list)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed input numbers (if any)
        for num in input_list:
            dut.num_in.value = num
            await RisingEdge(dut.clk)
        
        # Wait for done signal with timeout
        max_cycles = len(input_list) + 10
        done_seen = False
        for cycle in range(max_cycles):
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_seen = True
                break
            await RisingEdge(dut.clk)
        
        if not done_seen:
            raise TestFailure(f"Test {i+1}: Done signal not asserted within {max_cycles} cycles")
        
        # Check outputs are defined
        if not is_value_defined(dut.sum_result.value):
            raise TestFailure(f"Test {i+1}: sum_result is undefined")
        if not is_value_defined(dut.product_result.value):
            raise TestFailure(f"Test {i+1}: product_result is undefined")
        
        # Read results
        actual_sum = int(dut.sum_result.value)
        actual_product = int(dut.product_result.value)
        
        # Verify
        if actual_sum != expected_sum or actual_product != expected_product:
            raise TestFailure(
                f"Test {i+1} FAILED: Input={input_list}, "
                f"Expected sum={expected_sum}, product={expected_product}, "
                f"Got sum={actual_sum}, product={actual_product}"
            )
        
        passed += 1
        dut._log.info(f"Test {i+1} passed [OK]")
        
        # Small gap between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n{'='*40}")
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    dut._log.info(f"{'='*40}")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")