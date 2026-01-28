import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import cocotb.log

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_N = 16
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

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut, n):
    """Set n and start the computation."""
    dut.n.value = n
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def read_coordinates(dut, n):
    """Read coordinates from the DUT until done."""
    coords = []
    cycles = 0
    while cycles < MAX_CYCLES:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            x = safe_int(dut.x.value)
            y = safe_int(dut.y.value)
            index = safe_int(dut.index.value)
            coords.append((x, y, index))
            if index == n - 1:
                # All coordinates received
                break
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        cycles += 1
    else:
        raise TestFailure(f"Timeout while reading coordinates after {MAX_CYCLES} cycles")
    return coords

# ============================================================================
# TEST CASES
# ============================================================================

# Expected outputs for n=1 to 16 from the provided test cases
TEST_CASES = [
    (1, [(0, 0)]),
    (2, [(0, 0), (1, 0)]),  # Computed
    (3, [(0, 0), (1, 0), (1, 3)]),
    (4, [(0, 0), (1, 0), (1, 3), (2, 0)]),
    (5, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0)]),
    (6, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3)]),
    (7, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0)]),
    (8, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0), (5, 0)]),
    (9, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0), (5, 0), (5, 3)]),
    (10, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0), (5, 0), (5, 3), (6, 0)]),
    (11, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0), (5, 0), (5, 3), (6, 0), (7, 0)]),
    (12, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0), (5, 0), (5, 3), (6, 0), (7, 0), (7, 3)]),
    (13, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0), (5, 0), (5, 3), (6, 0), (7, 0), (7, 3), (8, 0)]),
    (14, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0), (5, 0), (5, 3), (6, 0), (7, 0), (7, 3), (8, 0), (9, 0)]),
    (15, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0), (5, 0), (5, 3), (6, 0), (7, 0), (7, 3), (8, 0), (9, 0), (9, 3)]),
    (16, [(0, 0), (1, 0), (1, 3), (2, 0), (3, 0), (3, 3), (4, 0), (5, 0), (5, 3), (6, 0), (7, 0), (7, 3), (8, 0), (9, 0), (9, 3), (10, 0)]),
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_knight_placement(dut):
    """Test knight placement module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for n, expected_coords in TEST_CASES:
        cocotb.log.info(f"\nTesting n={n}")
        
        try:
            # Start computation
            await start_computation(dut, n)
            
            # Read coordinates
            coords = await read_coordinates(dut, n)
            
            # Extract (x,y) pairs
            result_coords = [(x, y) for x, y, idx in sorted(coords, key=lambda t: t[2])]
            
            # Check length
            if len(result_coords) != n:
                raise TestFailure(f"Expected {n} coordinates, got {len(result_coords)}")
            
            # Check coordinates match
            for i, (x, y) in enumerate(result_coords):
                exp_x, exp_y = expected_coords[i]
                if x != exp_x or y != exp_y:
                    raise TestFailure(f"Coordinate {i}: expected ({exp_x}, {exp_y}), got ({x}, {y})")
            
            cocotb.log.info(f"  PASS: {n} coordinates correct")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")