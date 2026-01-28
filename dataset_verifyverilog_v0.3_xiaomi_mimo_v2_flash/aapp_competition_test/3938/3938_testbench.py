import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_ROWS = 16
MAX_COLS = 16
DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10

# ============================================================================
# COMPRESSION HELPERS
# ============================================================================
def compress_rectangles(rectangles):
    xs = set()
    ys = set()
    for (x1, y1, x2, y2) in rectangles:
        xs.add(x1)
        xs.add(x2+1)
        ys.add(y1)
        ys.add(y2+1)
    xx = sorted(xs)
    yy = sorted(ys)
    row_intervals = list(zip(yy[:-1], yy[1:]))
    col_intervals = list(zip(xx[:-1], xx[1:]))
    row_costs = [y2 - y1 for y1, y2 in row_intervals]
    col_costs = [x2 - x1 for x1, x2 in col_intervals]
    num_rows = len(row_intervals)
    num_cols = len(col_intervals)
    col_row_mask = [0] * num_cols
    for j, (x1, x2) in enumerate(col_intervals):
        mask = 0
        for i, (y1, y2) in enumerate(row_intervals):
            covered = False
            for (rx1, ry1, rx2, ry2) in rectangles:
                if rx1 <= x1 and ry1 <= y1 and rx2 >= x1 and ry2 >= y1:
                    covered = True
                    break
            if covered:
                mask |= (1 << i)
        col_row_mask[j] = mask
    return row_costs, col_costs, col_row_mask, num_rows, num_cols

# ============================================================================
# TEST CASES
# ============================================================================
test_cases = [
    ("Example 1", [(4,1,5,10), (1,4,10,5)], 4),
    ("Example 2", [(2,1,2,1), (4,2,4,3), (2,5,2,5), (2,3,5,3), (1,2,1,2), (3,2,5,3)], 3),
    ("No black cells", [], 0),
    ("Single cell", [(5,5,5,5)], 1),
]

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_cost_cover(dut):
    """Test the min_cost_cover module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for desc, rectangles, expected in test_cases:
        dut._log.info(f"Testing: {desc}")
        
        # Compress rectangles
        row_costs, col_costs, col_row_mask, num_rows, num_cols = compress_rectangles(rectangles)
        
        # Ensure sizes fit
        if num_rows > MAX_ROWS or num_cols > MAX_COLS:
            dut._log.warning(f"Skipping {desc}: compressed size ({num_rows},{num_cols}) exceeds MAX")
            continue
        
        # Drive inputs
        dut.r_cnt.value = num_rows
        dut.c_cnt.value = num_cols
        
        # Write row_cost
        for i in range(MAX_ROWS):
            if i < num_rows:
                dut.row_cost[i].value = row_costs[i]
            else:
                dut.row_cost[i].value = 0
        
        # Write col_cost
        for j in range(MAX_COLS):
            if j < num_cols:
                dut.col_cost[j].value = col_costs[j]
            else:
                dut.col_cost[j].value = 0
        
        # Write col_row_mask
        for j in range(MAX_COLS):
            if j < num_cols:
                dut.col_row_mask[j].value = col_row_mask[j]
            else:
                dut.col_row_mask[j].value = 0
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for cycle in range(10000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done in {desc}")
        
        # Read result
        if not is_value_defined(dut.min_cost.value):
            raise TestFailure(f"min_cost is undefined in {desc}")
        
        result = int(dut.min_cost.value)
        if result != expected:
            raise TestFailure(f"Test {desc}: expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")