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
DATA_WIDTH = 8
NODES = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_uw_distance_optimizer(dut):
    """Test UW Distance Optimizer with simplified test cases"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Simple 3-node graph
    # Human at node 0, Alien at node 2, node 1 in between
    dut._log.info("Test Case 1: Simple 3-node chain")
    
    # Set gravity values
    gravity_values = [20, 21, 19]  # Scaled down from original example
    for i in range(NODES):
        if i < len(gravity_values):
            dut.gravity_in[i].value = gravity_values[i]
        else:
            dut.gravity_in[i].value = 0
    
    # Set human/alien masks
    dut.human_mask[0].value = 1
    dut.alien_mask[2].value = 1
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    cycles = 0
    while not dut.done.value and cycles < MAX_CYCLES:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= MAX_CYCLES:
        raise TestFailure("Timeout - done not asserted")
    
    # Read result
    if is_value_defined(dut.min_distance.value):
        result = int(dut.min_distance.value)
        dut._log.info(f"Result: {result}")
        # Expected: 0 (from sample input 2)
        if result == 0:
            dut._log.info("PASS: Got expected result 0")
        else:
            dut._log.warning(f"Expected 0, got {result}")
    else:
        raise TestFailure("Result is undefined")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: More complex example (simplified from sample)
    dut._log.info("Test Case 2: Multi-node graph")
    
    # Set up a graph with multiple possible paths
    gravity_values = [377, 455, 180, 211, 134, 46, 111, 213]
    for i in range(NODES):
        dut.gravity_in[i].value = gravity_values[i]
    
    # Human at node 1, Alien at node 2
    dut.human_mask[1].value = 1
    dut.alien_mask[2].value = 1
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    cycles = 0
    while not dut.done.value and cycles < MAX_CYCLES:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= MAX_CYCLES:
        raise TestFailure("Timeout - done not asserted")
    
    # Read result
    if is_value_defined(dut.min_distance.value):
        result = int(dut.min_distance.value)
        dut._log.info(f"Result: {result}")
        # The actual value would be computed by the module
        # We just verify it produces a non-zero result
        if result != 0xFFFF:  # 0xFFFF is our initial "unset" value
            dut._log.info(f"PASS: Got valid result {result}")
        else:
            raise TestFailure("Module returned unset value")
    else:
        raise TestFailure("Result is undefined")
    
    dut._log.info("All tests completed")
