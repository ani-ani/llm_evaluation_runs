import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
GRID_ROWS = 4
GRID_COLS = 4
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10

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
# PACK GRID
# ============================================================================

def pack_grid(grid_flat, rows=GRID_ROWS, cols=GRID_COLS):
    packed = 0
    for r in range(rows):
        for c in range(cols):
            idx = r * cols + c
            val = grid_flat[r][c]
            val = clamp_to_width(val, DATA_WIDTH)
            packed |= (val & 0xFF) << (8 * idx)
    return packed

# ============================================================================
# RESET
# ============================================================================

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_baltic(dut):
    """Test the Baltic drain module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            "name": "Sample 1",
            "grid": [
                [-5,  2, -5,  0],
                [-1, -2, -1,  0],
                [ 5,  4, -5,  0],
                [ 0,  0,  0,  0]
            ],
            "drain_row": 1,
            "drain_col": 1,
            "expected": 10
        },
        {
            "name": "Sample 2 padded",
            "grid": [
                [-2, -3, -4,  0],
                [-3, -2, -3,  0],
                [ 0,  0,  0,  0],
                [ 0,  0,  0,  0]
            ],
            "drain_row": 1,
            "drain_col": 0,
            "expected": 16
        }
    ]
    
    for case in test_cases:
        cocotb.log.info(f"Running test: {case['name']}")
        
        # Pack the grid
        packed_grid = pack_grid(case['grid'])
        dut.grid_data.value = packed_grid
        dut.drain_row.value = case['drain_row']
        dut.drain_col.value = case['drain_col']
        dut.start.value = 1
        
        # Wait for one clock cycle to start
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        if has_signal(dut, 'done'):
            for _ in range(100):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done in {case['name']}")
        else:
            await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined in {case['name']}")
        
        result = int(dut.result.value)
        expected = case['expected']
        
        if result != expected:
            raise TestFailure(f"Test {case['name']} failed: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
        
        # Wait a few cycles before next test
        await Timer(CLK_PERIOD_NS * 2, units='ns')
    
    cocotb.log.info("All tests passed!")