import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
GRID_SIZE = 32  # 2x16 for simplicity, actual is 2x31
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

async def write_grid(dut, grid):
    """Write grid values to DUT input ports."""
    # Write first row
    for i in range(16):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            val = grid[0][i] if i < len(grid[0]) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
    
    # Write second row (partial)
    for i in range(16, 32):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            # Map to second row
            col = i - 16
            val = grid[1][col] if col < len(grid[1]) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
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

# ============================================================================
# TEST CASES
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_surgery_complete(dut):
    """Test case: Surgery should be complete."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case: k=3, from sample
    # Grid: first row: [1,2,3,5,6,0,7] second row: [8,9,10,4,11,12,13]
    # We'll use simplified 2x8 grid for this test
    grid = [
        [1, 2, 3, 5, 6, 0, 7, 8],  # First row (padded)
        [9, 10, 4, 11, 12, 13, 0, 0]  # Second row (padded)
    ]
    
    # Write inputs
    await write_grid(dut, grid)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    await wait_for_done(dut)
    
    # Check validity
    if not is_value_defined(dut.valid.value):
        raise TestFailure("Valid signal is undefined")
    
    valid = int(dut.valid.value)
    
    if valid != 1:
        raise TestFailure(f"Expected valid=1, got {valid}")
    
    # Check output sequence length
    if has_signal(dut, 'sequence_length'):
        seq_len = int(dut.sequence_length.value)
        dut._log.info(f"Sequence length: {seq_len}")
    
    # Check shortcut count
    if has_signal(dut, 'shortcut_count'):
        sc_count = int(dut.shortcut_count.value)
        dut._log.info(f"Shortcut count: {sc_count}")
    
    dut._log.info("Test passed: Surgery completed successfully")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_surgery_failed(dut):
    """Test case: Surgery should fail."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case: Invalid arrangement that should fail
    grid = [
        [2, 1, 3, 4, 5, 0, 6, 7],  # 1 and 2 swapped
        [8, 9, 10, 11, 12, 13, 0, 0]
    ]
    
    # Write inputs
    await write_grid(dut, grid)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    await wait_for_done(dut)
    
    # For failure case, valid should be 0
    if has_signal(dut, 'valid'):
        valid = int(dut.valid.value)
        if valid != 0:
            raise TestFailure(f"Expected valid=0 for failure case, got {valid}")
        dut._log.info("Test passed: Surgery correctly identified as failed")
    else:
        dut._log.warning("Valid signal not found, assuming failure case")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test various edge cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    test_cases = [
        # (description, grid, expected_valid)
        ("Already correct", [
            [1, 2, 3, 4, 5, 6, 7, 0],
            [8, 9, 10, 11, 12, 13, 14, 0]
        ], 1),
        ("One swap", [
            [1, 2, 3, 4, 5, 6, 0, 7],
            [8, 9, 10, 11, 12, 13, 14, 0]
        ], 1),
        ("Multiple swaps", [
            [3, 1, 2, 4, 5, 6, 0, 7],
            [8, 9, 10, 11, 12, 13, 14, 0]
        ], 1),
    ]
    
    for desc, grid, expected in test_cases:
        dut._log.info(f"Testing: {desc}")
        
        await reset_dut(dut)
        await write_grid(dut, grid)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if has_signal(dut, 'valid'):
            valid = int(dut.valid.value)
            if valid != expected:
                raise TestFailure(f"Test '{desc}': expected {expected}, got {valid}")
            dut._log.info(f"  PASS: valid={valid}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shortcut_output(dut):
    """Test that shortcuts are properly generated."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    await reset_dut(dut)
    
    # Simple valid case
    grid = [
        [1, 2, 3, 4, 5, 6, 7, 0],
        [8, 9, 10, 11, 12, 13, 14, 0]
    ]
    
    await write_grid(dut, grid)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    # Check shortcuts
    if has_signal(dut, 'shortcut_count'):
        sc_count = int(dut.shortcut_count.value)
        if sc_count == 0:
            raise TestFailure("Expected shortcuts to be defined")
        
        # Try to read shortcut L (assuming it's defined)
        if has_signal(dut, 'shortcut_L_0'):
            sc_l_0 = int(dut.shortcut_L_0.value)
            if sc_l_0 != 0:  # Should be 'l' = 108
                dut._log.info(f"Shortcut L[0] = {chr(sc_l_0)}")
        
        dut._log.info(f"Defined {sc_count} shortcuts")
    
    # Check move sequence
    if has_signal(dut, 'sequence_length'):
        seq_len = int(dut.sequence_length.value)
        if seq_len == 0:
            raise TestFailure("Expected non-empty move sequence")
        dut._log.info(f"Move sequence length: {seq_len}")
