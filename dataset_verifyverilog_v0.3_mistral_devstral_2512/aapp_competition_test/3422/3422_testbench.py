import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - matches Verilog parameters
# ============================================================================
MAX_PIECES = 4
MAX_W = 4
MAX_H = 4
MAX_AREA = 16
DATA_WIDTH = 4   # nibble width for digits and indices
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000   # allow long search

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE/READ HELPERS
# ============================================================================
async def write_piece_grid(dut, piece_idx, w, h, grid):
    """Write a piece's grid into the DUT (fixed 4x4 storage)."""
    for y in range(MAX_H):
        for x in range(MAX_W):
            if x < w and y < h:
                val = grid[y][x]   # grid is list of strings
                dut.piece_grid[piece_idx][x][y].value = clamp_to_width(val, DATA_WIDTH)
            else:
                dut.piece_grid[piece_idx][x][y].value = 0

async def read_output_grid(dut):
    """Read out_grid array from DUT."""
    results = []
    for i in range(MAX_AREA):
        if is_value_defined(dut.out_grid[i].value):
            results.append(int(dut.out_grid[i].value))
        else:
            results.append(None)
    return results

async def read_output_piece_map(dut):
    """Read out_piece_map array from DUT."""
    results = []
    for i in range(MAX_AREA):
        if is_value_defined(dut.out_piece_map[i].value):
            results.append(int(dut.out_piece_map[i].value))
        else:
            results.append(None)
    return results

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_treasure_map(dut):
    """Test the TreasureMapReconstructor with the first sample input."""
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    if not is_sequential:
        raise TestFailure("Design must be sequential with clk")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Sample Input 1
    # 3
    # 4 1
    # 2123
    # 2 2
    # 21
    # 10
    # 2 2
    # 23
    # 12
    
    # Parse pieces
    pieces = [
        {
            'w': 4, 'h': 1,
            'grid': ['2123']
        },
        {
            'w': 2, 'h': 2,
            'grid': ['21', '10']
        },
        {
            'w': 2, 'h': 2,
            'grid': ['23', '12']
        }
    ]
    
    # Write number of pieces
    dut.num_pieces.value = len(pieces)
    
    # Write each piece
    for i, piece in enumerate(pieces):
        # Write dimensions
        dut.piece_w[i].value = piece['w']
        dut.piece_h[i].value = piece['h']
        # Write grid
        await write_piece_grid(dut, i, piece['w'], piece['h'], piece['grid'])
    
    # Start computation
    await start_computation(dut)
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check valid
    if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
        raise TestFailure("Valid signal not asserted")
    
    # Read outputs
    out_w = int(dut.out_width.value)
    out_h = int(dut.out_height.value)
    out_grid = await read_output_grid(dut)
    out_map = await read_output_piece_map(dut)
    
    # Expected output for sample 1
    exp_w, exp_h = 4, 3
    exp_grid_flat = [2,1,2,3,  1,0,1,2,  2,1,2,3]   # row-major, 3 rows of 4
    exp_map_flat = [2,2,3,3,  2,2,3,3,  1,1,1,1]   # piece indices (1‑based)
    
    # Verify
    if out_w != exp_w or out_h != exp_h:
        raise TestFailure(f"Dimensions mismatch: expected {exp_w} {exp_h}, got {out_w} {out_h}")
    
    for i in range(exp_w * exp_h):
        if out_grid[i] != exp_grid_flat[i]:
            raise TestFailure(f"Grid cell {i}: expected {exp_grid_flat[i]}, got {out_grid[i]}")
        if out_map[i] != exp_map_flat[i]:
            raise TestFailure(f"Piece map cell {i}: expected {exp_map_flat[i]}, got {out_map[i]}")
    
    dut._log.info("Test passed: Sample input 1 reproduced correctly.")
