import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_network_optimizer(dut):
    """Test network optimizer with various tree configurations."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (diam1, diam2, diam3, diam4, num_trees, expected_result, description)
    test_cases = [
        # Original problem examples (adapted)
        # Tree 1: 0-1-0 (diam=1, radius=1)
        # Tree 2: 0-2-0 (diam=1, radius=1)  
        # Tree 3: 3-4-5 (diam=2, radius=1)
        # Actually original example: 0-1, 0-2 (diam=2, radius=1), 3-4,3-5 (diam=2, radius=1)
        # Result after connecting: 0-1-0-3-4 or 0-2-0-3-5: max hops 3
        (2, 2, 0, 0, 2, 3, "Two trees of diameter 2 each"),
        
        # Second example: 11 computers, 9 cables -> multiple trees
        # Simplified: 3 trees with diameters 2,2,2 -> result 3
        (2, 2, 2, 0, 3, 4, "Three trees of diameter 2 each"),
        
        # Additional test cases
        (1, 0, 0, 0, 1, 1, "Single tree, diameter 1"),
        (3, 0, 0, 0, 1, 3, "Single tree, diameter 3"),
        (2, 3, 0, 0, 2, 4, "Two trees: diam 2 and 3"),
        (4, 4, 4, 0, 3, 5, "Three trees of diameter 4 each"),
        (2, 2, 2, 2, 4, 4, "Four trees of diameter 2 each"),
        (5, 3, 2, 1, 4, 6, "Four trees of different diameters"),
        (1, 1, 1, 1, 4, 3, "Four single-edge trees"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (d1, d2, d3, d4, num_t, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set inputs
            dut.diam1.value = d1
            dut.diam2.value = d2
            dut.diam3.value = d3
            dut.diam4.value = d4
            dut.num_trees.value = num_t
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
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