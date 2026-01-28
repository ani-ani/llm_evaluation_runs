import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
R = 4
C = 4
GRID_WIDTH = R * C
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def pack_grid(bomb_coords):
    """
    Pack list of (r,c) coordinates into a grid vector.
    Bits are ordered row-major: bit index = r*C + c.
    """
    grid = 0
    for (r, c) in bomb_coords:
        idx = r * C + c
        grid |= (1 << idx)
    return grid

async def reset_dut(dut):
    """Reset DUT (active-low)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# TEST CASES
# ============================================================================

test_cases = [
    # (description, bomb_coords, expected_result)
    ("Single bomb", [(0,0)], 0),
    ("Two bombs in same row", [(0,0), (0,1)], 1),
    ("Two bombs in same column", [(0,0), (1,0)], 1),
    ("Three bombs path", [(0,0), (0,1), (1,1)], 2),
    ("Example 1", [(0,0), (1,1), (2,0), (2,2)], 2),
    ("Example 2", [(0,1), (0,2), (1,0), (2,0), (2,3)], 3),
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bomb_disarm(dut):
    """Test bomb disarm module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for desc, bomb_coords, expected in test_cases:
        dut._log.info(f"Test: {desc}")
        
        # Pack grid
        grid_val = pack_grid(bomb_coords)
        dut.grid.value = grid_val
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined")
        
        result = int(dut.result.value)
        
        if result != expected:
            dut._log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")