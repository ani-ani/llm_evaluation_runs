import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Match the Verilog module parameters
# ============================================================================
N = 8          # Maximum rows
M = 8          # Maximum columns
NM = N * M     # Total cells
NODES = N + M  # Total nodes in DSU
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000  # Should be enough for 64 cells * ~16 cycles per find

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# GRID PACKING HELPERS
# ============================================================================

def pack_grid(n, m, elements):
    """
    Pack the grid into a 64-bit integer.
    elements is a list of (r, c) tuples (1-indexed).
    Returns the packed integer.
    """
    grid_val = 0
    for (r, c) in elements:
        i = r - 1  # 0-indexed row
        j = c - 1  # 0-indexed column
        if i < N and j < M:
            pos = i * M + j
            grid_val |= (1 << pos)
    return grid_val

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_chemical_table(dut):
    """Test the chemical_table module with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, elements, expected_answer)
    test_cases = [
        # Example 1: 2x2 grid, 3 elements -> answer 0
        (2, 2, [(1,2), (2,2), (2,1)], 0),
        # Example 2: 1x5 grid, 3 elements -> answer 2
        (1, 5, [(1,1), (1,3), (1,5)], 2),
        # Example 3: 4x3 grid, 6 elements -> answer 1
        (4, 3, [(1,2), (1,3), (2,2), (2,3), (3,1), (3,3)], 1),
        # Edge case: 8x8 grid, no elements -> answer = n + m - 1 = 15
        (8, 8, [], 15),
        # Edge case: 2x2 grid, all elements -> answer 0
        (2, 2, [(1,1), (1,2), (2,1), (2,2)], 0),
        # Edge case: 2x2 grid, 2 diagonal elements -> answer 1 (need to purchase one to start fusion)
        (2, 2, [(1,1), (2,2)], 1),
        # Additional case: 3x3 grid, 5 elements (example from problem)
        (3, 3, [(1,3), (2,3), (2,2), (3,2), (3,1)], 0),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (n, m, elements, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest {idx+1}: n={n}, m={m}, elements={elements}, expected={expected}")
        
        # Pack grid
        grid_val = pack_grid(n, m, elements)
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        dut.grid.value = grid_val
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read answer
        if not is_value_defined(dut.answer.value):
            dut._log.error("Answer is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.answer.value)
        
        if result != expected:
            dut._log.error(f"FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"PASS: Got {result}")
            passed += 1
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")