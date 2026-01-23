import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 3
ARRAY_SIZE = 16
K_MAX = 5
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_query_processor(dut):
    """Test query processor with updates and subarray queries"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Helper to execute update
    async def execute_update(pos, val):
        dut.query_type.value = 1
        dut.update_pos.value = pos - 1  # Convert to 0-indexed
        dut.update_value.value = val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    
    # Helper to execute query type 2
    async def execute_query():
        dut.query_type.value = 2
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        return int(dut.result.value)
    
    # Test case 1: Initial array [2,3,1,2], query -> 3
    dut._log.info("Test case 1: Initial array [2,3,1,2]")
    
    # Initialize array with updates
    await execute_update(1, 2)  # Position 1 = 2
    await execute_update(2, 3)  # Position 2 = 3  
    await execute_update(3, 1)  # Position 3 = 1
    await execute_update(4, 2)  # Position 4 = 2
    
    # Query - should return 3
    result = await execute_query()
    if result != 3:
        raise TestFailure(f"Expected 3, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    # Update position 3 to 3
    dut._log.info("Update position 3 to 3")
    await execute_update(3, 3)
    
    # Query - should return -1
    result = await execute_query()
    if result != -1:
        raise TestFailure(f"Expected -1, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    # Update position 1 to 1
    dut._log.info("Update position 1 to 1")
    await execute_update(1, 1)
    
    # Query - should return 4
    result = await execute_query()
    if result != 4:
        raise TestFailure(f"Expected 4, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    # Test case 2: Additional test from example
    dut._log.info("Test case 2: Array [1,2,3,2,1,1]")
    
    # Reset and initialize
    await reset_dut(dut)
    await execute_update(1, 1)
    await execute_update(2, 2)
    await execute_update(3, 3)
    await execute_update(4, 2)
    await execute_update(5, 1)
    await execute_update(6, 1)
    
    # Query - should return 3
    result = await execute_query()
    if result != 3:
        raise TestFailure(f"Expected 3, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    # Update position 2 to 1
    await execute_update(2, 1)
    
    # Query - should return 3
    result = await execute_query()
    if result != 3:
        raise TestFailure(f"Expected 3, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    # Update position 4 to 1
    await execute_update(4, 1)
    # Update position 6 to 2
    await execute_update(6, 2)
    
    # Query - should return 4
    result = await execute_query()
    if result != 4:
        raise TestFailure(f"Expected 4, got {result}")
    dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("All tests passed!")