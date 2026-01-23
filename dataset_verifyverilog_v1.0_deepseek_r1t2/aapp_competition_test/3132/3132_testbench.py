import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 3
ARRAY_SIZE = 9
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
async def test_find_squares_3x3(dut):
    """Test the find_squares_3x3 module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (grid_row0, grid_row1, grid_row2, expected outputs)
    # Outputs are (sq1_row, sq1_col, sq1_size, sq2_row, sq2_col, sq2_size)
    test_cases = [
        (
            0b110,  # row0: xx.
            0b111,  # row1: xxx
            0b000,  # row2: ...
            (0, 0, 2, 1, 2, 1),  # Expected: sq1 (0,0,2), sq2 (1,2,1)
            "Sample 1: 3x3 grid with two squares"
        ),
        (
            0b111,  # row0: xxx
            0b111,  # row1: xxx
            0b111,  # row2: xxx
            (0, 0, 3, 0, 0, 1),  # One possible solution: full square and one cell
            "Full grid"
        ),
        (
            0b100,  # row0: x..
            0b000,  # row1: ...
            0b000,  # row2: ...
            (0, 0, 1, 0, 0, 1),  # Both squares are the same single cell
            "Single cell"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (r0, r1, r2, expected, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        dut._log.info(f"  Grid: row0={bin(r0)}, row1={bin(r1)}, row2={bin(r2)}")
        
        try:
            # Set grid inputs
            dut.grid_row0.value = r0
            dut.grid_row1.value = r1
            dut.grid_row2.value = r2
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            if not all(is_value_defined(dut.square1_row.value),
                       is_value_defined(dut.square1_col.value),
                       is_value_defined(dut.square1_size.value),
                       is_value_defined(dut.square2_row.value),
                       is_value_defined(dut.square2_col.value),
                       is_value_defined(dut.square2_size.value)):
                raise TestFailure("Output signals are undefined (X/Z)")
            
            sq1_row = int(dut.square1_row.value)
            sq1_col = int(dut.square1_col.value)
            sq1_size = int(dut.square1_size.value)
            sq2_row = int(dut.square2_row.value)
            sq2_col = int(dut.square2_col.value)
            sq2_size = int(dut.square2_size.value)
            
            # Check if outputs match expected
            actual = (sq1_row, sq1_col, sq1_size, sq2_row, sq2_col, sq2_size)
            
            # Since there might be multiple solutions, we just check that the squares cover all x's
            # But for simplicity, we check exact match with expected if given
            if actual == expected:
                dut._log.info(f"  PASS: outputs = {actual}")
                passed += 1
            else:
                # If not exact match, verify that the squares are valid and cover all x's
                # Compute x_mask from grid
                x_mask = (r2 << 6) | (r1 << 3) | r0
                # Compute mask for each square
                def get_mask(row, col, size):
                    mask = 0
                    for r in range(row, row+size):
                        for c in range(col, col+size):
                            pos = r*3 + c
                            mask |= (1 << pos)
                    return mask
                mask1 = get_mask(sq1_row, sq1_col, sq1_size)
                mask2 = get_mask(sq2_row, sq2_col, sq2_size)
                combined = mask1 | mask2
                if combined == x_mask:
                    dut._log.info(f"  PASS: outputs = {actual} (covers all x's)")
                    passed += 1
                else:
                    raise TestFailure(f"Outputs {actual} do not cover all x's. Expected coverage {bin(x_mask)}, got {bin(combined)}")
        
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")