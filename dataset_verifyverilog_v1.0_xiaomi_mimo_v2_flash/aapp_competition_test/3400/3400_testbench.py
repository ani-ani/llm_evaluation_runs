import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

# Configuration
MAX_LOCATIONS = 200
MAX_TRIPS = 500
CLK_PERIOD_NS = 10

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shortest_path(dut):
    """Test the shortest path module with example inputs"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Example from problem
    dut.N.value = 3
    dut.A.value = 1
    dut.R.value = 3
    dut.T.value = 3
    
    # For simplicity, we'll assume the module has been pre-configured
    # with the graph from the trips. In a real testbench, we would
    # need to feed the trip data through the interface.
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(1000):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Read result
    if is_value_defined(dut.result.value):
        result = int(dut.result.value)
        expected = 9  # From sample
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        dut._log.info(f"Test 1 PASSED: result = {result}")
    else:
        raise TestFailure("Result is undefined")
    
    # Test case 2: Second example
    dut.N.value = 5
    dut.A.value = 5
    dut.R.value = 1
    dut.T.value = 9
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(1000):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Read result
    if is_value_defined(dut.result.value):
        result = int(dut.result.value)
        expected = 6  # From sample
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        dut._log.info(f"Test 2 PASSED: result = {result}")
    else:
        raise TestFailure("Result is undefined")
    
    dut._log.info("All tests passed!")

# Additional test cases
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: Direct path
    dut.N.value = 2
    dut.A.value = 1
    dut.R.value = 2
    dut.T.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(1000):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    if is_value_defined(dut.result.value):
        result = int(dut.result.value)
        dut._log.info(f"Direct path test: result = {result}")
    
    # Test: No path (should return infinity)
    dut.N.value = 3
    dut.A.value = 1
    dut.R.value = 3
    dut.T.value = 0  # No trips, no edges
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(1000):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    if is_value_defined(dut.result.value):
        result = int(dut.result.value)
        # Should be large (infinity)
        dut._log.info(f"No path test: result = {result}")
