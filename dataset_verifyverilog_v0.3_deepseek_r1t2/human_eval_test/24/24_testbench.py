import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to wait for valid output with timeout
async def wait_for_valid_output(dut, signal, timeout_ns=10000):
    elapsed = 0
    while elapsed < timeout_ns:
        await Timer(10, units='ns')
        elapsed += 10
        if is_value_defined(signal.value):
            return int(signal.value)
    raise TestFailure(f"Timeout: output not valid after {timeout_ns}ns")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_largest_divisor(dut):
    """Test largest_divisor module with multiple test cases"""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_n, expected_result)
    test_cases = [
        (3, 1),
        (7, 1),
        (10, 5),
        (100, 50),
        (49, 7),
        (1, 1),  # Edge case
        (16, 8), # Additional test
        (15, 5), # From docstring
    ]
    
    total_tests = len(test_cases)
    passed_tests = 0
    
    dut._log.info(f"Starting {total_tests} test cases...")
    
    for i, (input_n, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: n={input_n}, expected={expected}")
        
        # Apply input
        dut.n.value = input_n
        await RisingEdge(dut.clk)
        
        # Assert start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (with timeout)
        MAX_CYCLES = 300  # Safe upper bound
        done_received = False
        
        for cycle in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            
            # Check if done is defined
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {i+1}: done signal not asserted after {MAX_CYCLES} cycles")
        
        # Verify output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: result has undefined value (X/Z)")
        
        # Read and verify result
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: n={input_n}, expected={expected}, got={result}")
        
        dut._log.info(f"  PASSED: got {result}")
        passed_tests += 1
        
        # Wait one more cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nTest Summary: {passed_tests}/{total_tests} tests passed")
    
    if passed_tests == total_tests:
        raise TestSuccess("All tests passed!")
    else:
        raise TestFailure(f"Some tests failed. Passed: {passed_tests}/{total_tests}")
