import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
N_MAX = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Helper to write c values to the DUT
async def write_c_values(dut, n, c_values):
    """Write the c values to the DUT inputs."""
    dut.n.value = n
    
    # Map values to individual inputs
    value_map = {0: 'c0', 1: 'c1', 2: 'c2', 3: 'c3', 
                 4: 'c4', 5: 'c5', 6: 'c6', 7: 'c7'}
    
    for i, val in enumerate(c_values):
        if i < 8:
            port_name = value_map[i]
            if hasattr(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tree_checker(dut):
    """Test the tree_checker module with various test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, c_values, expected_result, description)
    test_cases = [
        (1, [1], "YES", "Single node"),
        (4, [1, 1, 1, 4], "YES", "Example 1: star tree"),
        (5, [1, 1, 5, 2, 1], "NO", "Example 2: has value 2"),
        (3, [1, 1, 3], "YES", "Three nodes"),
        (2, [1, 2], "NO", "Two nodes: invalid (2 in middle)"),
        (4, [1, 1, 3, 4], "YES", "Four nodes: chain"),
        (3, [1, 3, 3], "NO", "Three nodes: two roots"),
        (4, [1, 3, 4, 4], "NO", "Four nodes: two large roots"),
        (6, [1, 1, 1, 3, 3, 6], "YES", "Six nodes: valid structure"),
        (6, [1, 1, 1, 3, 6, 6], "NO", "Six nodes: two roots"),
        (7, [1, 1, 1, 1, 1, 3, 7], "YES", "Seven nodes: star with intermediate"),
        (7, [1, 1, 1, 1, 1, 2, 7], "NO", "Seven nodes: has value 2"),
        (8, [1, 1, 1, 1, 1, 3, 3, 8], "YES", "Eight nodes: valid"),
        (8, [1, 1, 1, 1, 3, 3, 3, 8], "NO", "Eight nodes: invalid structure"),
        (1, [1], "YES", "Single node (repeated)"),
        (4, [1, 1, 1, 4], "YES", "Example 1 (repeated)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, c_values, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            await write_c_values(dut, n, c_values)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.yes.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = "YES" if int(dut.yes.value) == 1 else "NO"
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
