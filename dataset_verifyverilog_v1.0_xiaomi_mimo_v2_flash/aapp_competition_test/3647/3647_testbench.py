import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
DATA_WIDTH = 2
CELL_COUNT = 16
DIST_WIDTH = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Cell types
OBST = 0
GRAVEL = 1
ICE = 2
GOAL = 3

# ============================================================================
# MANDATORY HELPER FUNCTIONS

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# GRID PACKING/UNPACKING

def pack_grid(grid, rows=4, cols=4, cell_width=2):
    packed = 0
    for r in range(rows):
        for c in range(cols):
            val = grid[r][c]
            idx = r * cols + c
            packed |= (val & ((1 << cell_width) - 1)) << (idx * cell_width)
    return packed

def unpack_distances(packed_val, num_cells=CELL_COUNT, cell_width=DIST_WIDTH):
    distances = []
    for i in range(num_cells):
        bits = (packed_val >> (i * cell_width)) & ((1 << cell_width) - 1)
        distances.append(to_signed(bits, cell_width))
    return distances

# ============================================================================
# SEQUENTIAL HELPERS

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ice_maze_solver(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (grid_4x4, expected_distances_16, description)
    test_cases = [
        (
            [
                [OBST, OBST, OBST, OBST],
                [OBST, GOAL, GRAVEL, OBST],
                [OBST, ICE, OBST, OBST],
                [OBST, OBST, OBST, OBST]
            ],
            [
                -1, -1, -1, -1,
                -1,  0,  1, -1,
                -1,  1, -1, -1,
                -1, -1, -1, -1
            ],
            "Simple 4x4 with goal and gravel"
        ),
        (
            [
                [OBST, OBST, OBST, OBST],
                [OBST, GOAL, ICE, OBST],
                [OBST, ICE, ICE, OBST],
                [OBST, OBST, OBST, OBST]
            ],
            [
                -1, -1, -1, -1,
                -1,  0,  1, -1,
                -1,  1,  1, -1,
                -1, -1, -1, -1
            ],
            "Goal with adjacent ice"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Pack and set grid
            packed_grid = pack_grid(grid)
            dut.grid_data.value = packed_grid
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.distances_data.value):
                raise TestFailure("distances_data undefined")
            
            packed_distances = int(dut.distances_data.value)
            distances = unpack_distances(packed_distances)
            
            # Verify each cell
            for idx, (got, exp) in enumerate(zip(distances, expected)):
                if got != exp:
                    row = idx // 4
                    col = idx % 4
                    raise TestFailure(
                        f"Cell ({row},{col}): expected {exp}, got {got}"
                    )
            
            cocotb.log.info(f"  PASS: {len(distances)} cells correct")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
