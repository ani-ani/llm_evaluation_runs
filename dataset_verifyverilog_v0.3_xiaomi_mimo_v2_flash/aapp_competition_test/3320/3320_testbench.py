import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
NODE_WIDTH = 3
EDGE_IDX_WIDTH = 4
N = 4               # Number of nodes in test graph
M = 7               # Number of edges in test graph
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

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
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CUSTOM HELPER FUNCTIONS FOR THIS TESTBENCH
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'config_en'):
        dut.config_en.value = 0
    if has_signal(dut, 'load_done'):
        dut.load_done.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_edge(dut, u, v, w):
    """Load a single edge into the DUT."""
    dut.config_en.value = 1
    dut.config_u.value = clamp_to_width(u, NODE_WIDTH)
    dut.config_v.value = clamp_to_width(v, NODE_WIDTH)
    dut.config_w.value = clamp_to_width(w, DATA_WIDTH)
    await RisingEdge(dut.clk)
    dut.config_en.value = 0
    await RisingEdge(dut.clk)  # small gap

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def run_query(dut, s, t, expected):
    """Run a single query and verify result."""
    # Start pulse
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure(f"Result is undefined (X/Z)")
    result = int(dut.result.value)
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    dut._log.info(f"Query s={s} t={t}: result = {result} [PASS]")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_minimal_or_path(dut):
    """Test the minimal OR path module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # ========================================================================
    # LOAD GRAPH
    # ========================================================================
    # Example graph from the problem (converted to 0‑indexed nodes):
    # Nodes: 0,1,2,3 (cities 1,2,3,4)
    # Edges: (u,v,w)
    edges = [
        (0, 1, 1),
        (0, 1, 3),
        (0, 2, 2),
        (0, 3, 1),
        (1, 2, 4),
        (1, 3, 4),
        (2, 3, 4),
    ]
    
    dut._log.info(f"Loading {len(edges)} edges...")
    for (u, v, w) in edges:
        await load_edge(dut, u, v, w)
    
    # Signal that loading is complete
    dut.load_done.value = 1
    await RisingEdge(dut.clk)
    dut.load_done.value = 0
    await RisingEdge(dut.clk)
    
    # ========================================================================
    # DEFINE TEST CASES
    # ========================================================================
    test_cases = [
        (0, 1, 1),   # city1 -> city2
        (0, 2, 2),   # city1 -> city3
        (2, 3, 3),   # city3 -> city4
    ]
    
    dut._log.info("Running queries...")
    passed = 0
    failed = 0
    
    for (s, t, expected) in test_cases:
        try:
            await run_query(dut, s, t, expected)
            passed += 1
        except TestFailure as e:
            dut._log.error(f"Query failed: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    dut._log.info("All tests passed!")