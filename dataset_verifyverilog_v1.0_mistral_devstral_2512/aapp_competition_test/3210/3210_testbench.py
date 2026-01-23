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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# PARSING HELPER
# ============================================================================

def parse_ascii_to_edges(ascii_str):
    """Parse the ASCII representation for N=3 and return 12-bit edge vector."""
    lines = ascii_str.strip().split('\n')
    # First line is N, we ignore it for this test
    grid = lines[1:]  # skip N line
    if len(grid) != 5:
        raise ValueError(f"Expected 5 rows for N=3, got {len(grid)}")
    
    edge_vec = 0
    # Helper to set bit
    def set_bit(pos, idx):
        nonlocal edge_vec
        if grid[pos[0]][pos[1]] == '-' or grid[pos[0]][pos[1]] == '|':
            edge_vec |= (1 << idx)
    
    # Horizontal edges
    # (0,1): index 0
    set_bit((0,1), 0)
    # (0,3): index 1
    set_bit((0,3), 1)
    # (2,1): index 2
    set_bit((2,1), 2)
    # (2,3): index 3
    set_bit((2,3), 3)
    # (4,1): index 4
    set_bit((4,1), 4)
    # (4,3): index 5
    set_bit((4,3), 5)
    
    # Vertical edges
    # (1,0): index 6
    set_bit((1,0), 6)
    # (1,2): index 8
    set_bit((1,2), 8)
    # (1,4): index 10
    set_bit((1,4), 10)
    # (3,0): index 7
    set_bit((3,0), 7)
    # (3,2): index 9
    set_bit((3,2), 9)
    # (3,4): index 11
    set_bit((3,4), 11)
    
    return edge_vec

# ============================================================================
# TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_dots_and_boxes(dut):
    """Test the dots_and_boxes module with the example input."""
    
    # Start clock (10 ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Example input for N=3
    input_str = "3\n*-*.*\n|.|.|\n*.*-*\n|...|\n*.*.*"
    
    # Parse to edges
    edge_vector = parse_ascii_to_edges(input_str)
    dut._log.info(f"Parsed edge vector: 0x{edge_vector:03X}")
    
    # Assign to DUT
    if has_signal(dut, 'edges'):
        dut.edges.value = edge_vector
    else:
        raise TestFailure("DUT does not have 'edges' signal")
    
    # Pulse start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not (has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1):
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 100000:
            raise TestFailure("Timeout waiting for done")
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
    
    result = int(dut.result.value)
    expected = 3
    
    if result != expected:
        raise TestFailure(f"Result mismatch: expected {expected}, got {result}")
    
    dut._log.info(f"Test passed: result = {result}")