import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
COORD_WIDTH = 4    # Bits for coordinates (1-8)
DIST_WIDTH = 7     # Bits for squared distance (max 98)
MAX_TREES = 24     # Maximum number of trees
CLK_PERIOD_NS = 10
MAX_CYCLES = 100   # Max cycles to wait for done

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
    if has_signal(dut, 'load_en'):
        dut.load_en.value = 0
    if has_signal(dut, 'process'):
        dut.process.value = 0
    
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_apple_distance(dut):
    """Test the apple distance module with problem example."""
    
    # Detect interface
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must be sequential with clk")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case from problem example
    # Initial tree: (1,1)
    # Queries: (1,3), (1,1), (3,2)
    # Expected: 4, 0, 5
    
    test_cases = [
        (1, 3, 4, "Apple falls at (1,3)"),
        (1, 1, 0, "Apple falls at (1,1)"),
        (3, 2, 5, "Apple falls at (3,2)"),
    ]
    
    # Load initial tree
    if has_signal(dut, 'load_en'):
        dut._log.info("Loading initial tree at (1,1)")
        dut.r.value = 1
        dut.s.value = 1
        dut.load_en.value = 1
        await RisingEdge(dut.clk)
        dut.load_en.value = 0
        await RisingEdge(dut.clk)  # Return to IDLE
    else:
        raise TestFailure("Missing load_en signal")
    
    if not has_signal(dut, 'process'):
        raise TestFailure("Missing process signal")
    
    passed = 0
    failed = 0
    
    for i, (q_r, q_s, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        try:
            # Send query
            dut.r.value = q_r
            dut.s.value = q_s
            dut.process.value = 1
            await RisingEdge(dut.clk)
            dut.process.value = 0
            
            # Wait for computation
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.distance.value):
                raise TestFailure("Distance output undefined (X/Z)")
            
            result = int(dut.distance.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: distance = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
