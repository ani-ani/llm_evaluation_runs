import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

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

# ============================================================================
# TEST CASES
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_producer_routing(dut):
    """Test producer routing module with sample inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases adapted from problem
    test_cases = [
        # (N, K, M, edges, expected_output)
        {
            'N': 4, 'K': 2, 'M': 3,
            'edges': [(1,3), (2,3), (3,4)],
            'expected': 2
        },
        {
            'N': 5, 'K': 2, 'M': 4,
            'edges': [(1,3), (3,4), (2,4), (4,5)],
            'expected': 1
        },
        {
            'N': 5, 'K': 2, 'M': 6,
            'edges': [(1,4), (2,3), (3,4), (4,5), (2,4), (3,3)],
            'expected': 2
        }
    ]
    
    for i, test in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}: N={test['N']}, K={test['K']}, M={test['M']}")
        
        # Reset for each test case
        await reset_dut(dut)
        
        # Build graph by feeding edges
        dut.prod_id.value = 0
        dut.edge_u.value = 0
        dut.edge_v.value = 0
        dut.edge_valid.value = 0
        
        # Feed edges
        for edge in test['edges']:
            dut.edge_u.value = edge[0]
            dut.edge_v.value = edge[1]
            dut.edge_valid.value = 1
            await RisingEdge(dut.clk)
            dut.edge_valid.value = 0
            await RisingEdge(dut.clk)
        
        # Feed producer information
        for j in range(1, test['K']+1):
            dut.prod_id.value = j
            await RisingEdge(dut.clk)
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.max_producers.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.max_producers.value)
        expected = test['expected']
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("All tests passed!")
