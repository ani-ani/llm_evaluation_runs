import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    """Check if a signal exists on the DUT."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=200, timeout_unit='ms')
async def test_sum_at_most_two_digits(dut):
    """Test the sum_at_most_two_digits module."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Helper function to wait for done signal
    async def wait_for_done(max_cycles=20):
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                return True
        return False
    
    # Helper function to set array values
    def set_array_values(values):
        """Set array elements (supports up to 16 elements)."""
        for i in range(16):
            if i < len(values):
                dut.arr[i].value = values[i]
            else:
                dut.arr[i].value = 0
    
    # Helper function to get result
    def get_result():
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined (X/Z)")
        return int(dut.result.value)
    
    # Test cases adapted for 16-element array
    test_cases = [
        # (arr, k, expected_sum, description)
        ([1, -2, -3, 41, 57, 76, 87, 88, 99, 0, 0, 0, 0, 0, 0, 0], 3, -4, "Negative numbers, should sum 1 + (-2) + (-3) = -4"),
        ([111, 121, 3, 4000, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 2, 0, "Both >=100, sum should be 0"),
        ([11, 21, 3, 90, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0, 0], 4, 125, "All <100 in first 4: 11+21+3+90=125"),
        ([111, 21, 3, 4000, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0, 0], 4, 24, "Mixed: 21+3=24"),
        ([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1, 1, "Single element <100"),
        ([100, 99, 101, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 4, 149, "Boundary: 100 is NOT included, 99+50=149"),
        ([255, 256, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 2, 255, "99 is max, 100+ should be excluded"),
    ]
    
    dut._log.info("Starting test sequence...")
    
    # Initial reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for i, (arr_vals, k_val, expected, desc) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {desc}")
        
        # Set up inputs
        set_array_values(arr_vals)
        dut.k.value = k_val
        
        # Wait one cycle for inputs to stabilize
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        success = await wait_for_done(max_cycles=25)
        
        if not success:
            raise TestFailure(f"Test {i+1}: Timeout - done signal not asserted")
        
        # Read result
        result = get_result()
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"Test {i+1} PASSED: Result = {result}")
        passed += 1
        
        # Wait for done to go low before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")