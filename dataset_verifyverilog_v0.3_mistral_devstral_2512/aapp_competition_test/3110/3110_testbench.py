import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4      # 4 bits for digits 1-9
ROWS = 3
COLS = 3
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_grid(dut, grid):
    """Write 3x3 grid to DUT."""
    # Try 2D array first: grid[i][j]
    try:
        for i in range(ROWS):
            for j in range(COLS):
                dut.grid[i][j].value = clamp_to_width(grid[i][j], DATA_WIDTH)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports: grid_i_j
    for i in range(ROWS):
        for j in range(COLS):
            port_name = f"grid_{i}_{j}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(grid[i][j], DATA_WIDTH)
            else:
                raise TestFailure(f"Cannot find grid port: grid[{i}][{j}] or {port_name}")

async def read_result(dut):
    """Read result from DUT."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    if not has_signal(dut, 'done'):
        # Combinational module
        await Timer(100, units='ns')
        return
    
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    if not has_signal(dut, 'start'):
        return
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=20000, timeout_unit="ms")
async def test_scroll_code(dut):
    """Test the scroll code solver module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    has_start = has_signal(dut, 'start')
    has_rst = has_signal(dut, 'rst_n')
    
    cocotb.log.info(f"Sequential: {is_sequential}, Start: {has_start}, Reset: {has_rst}")
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Test cases for 3x3 grids: (grid, expected_count, description)
    test_cases = [
        (
            [
                [1, 2, 4],
                [0, 3, 6],
                [4, 0, 3]
            ],
            2,
            "Example 1: 3x3 with 2 unknowns"
        ),
        (
            [
                [1, 2, 3],
                [4, 5, 6],
                [7, 8, 9]
            ],
            0,
            "Complete grid - check validity"
        ),
        (
            [
                [1, 3, 0],
                [2, 0, 5],
                [0, 4, 6]
            ],
            1,
            "3x3 with 3 unknowns - one solution"
        ),
        (
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]
            ],
            0,
            "All zeros - should find no valid solutions"
        ),
        (
            [
                [1, 2, 4],
                [3, 0, 6],
                [4, 1, 3]
            ],
            0,
            "Invalid partial - no solutions"
        ),
        (
            [
                [1, 2, 4],
                [0, 0, 6],
                [4, 0, 3]
            ],
            0,
            "3x3 with 3 unknowns - no solutions"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"Grid:")
        for row in grid:
            cocotb.log.info(f"  {row}")
        
        try:
            # Write grid
            await write_grid(dut, grid)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            result = await read_result(dut)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")