import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 4
RESULT_WIDTH = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# SEQUENTIAL HELPERS
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
# TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_grasshopper(dut):
    """Test the grasshopper module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Helper to assign grid values
    def assign_grid(grid):
        """Assign a 4x4 grid to the DUT."""
        for r in range(4):
            for c in range(4):
                signal_name = f'grid_{r}_{c}'
                if has_signal(dut, signal_name):
                    # Clamp to 8 bits
                    val = clamp_to_width(grid[r][c], DATA_WIDTH)
                    getattr(dut, signal_name).value = val
                else:
                    raise TestFailure(f"Signal {signal_name} not found")
    
    # Test cases: (start_row, start_col, grid_4x4, expected_length, description)
    test_cases = [
        (
            1, 1,  # start at (1,1) -> 0-indexed (0,0)
            [
                [1, 2, 3, 4],
                [2, 3, 4, 5],
                [3, 4, 5, 6],
                [4, 5, 6, 7]
            ],
            4,
            "Sample input 4x4"
        ),
        (
            0, 0,  # start at (1,1) -> 0-indexed (0,0)
            [
                [1, 1, 1, 1],
                [1, 1, 1, 1],
                [1, 1, 1, 1],
                [1, 1, 1, 1]
            ],
            1,
            "All equal petals"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (start_r, start_c, grid, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Start position: row={start_r}, col={start_c}")
        
        try:
            # Assign grid
            assign_grid(grid)
            
            # Assign start position (0-indexed)
            dut.start_row.value = start_r
            dut.start_col.value = start_c
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.max_length.value):
                raise TestFailure("max_length is undefined (X/Z)")
            
            result = int(dut.max_length.value)
            
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