import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 12
ARRAY_SIZE = 8
RESULT_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# HELPER FUNCTIONS (as per rules)
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
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE/READ HELPERS (for individual ports)
# ============================================================================
async def write_points(dut, n, x_vals, y_vals):
    """Write n points to x0..x7 and y0..y7 ports."""
    for i in range(8):
        if i < n:
            # Use getattr to handle individual ports
            if has_signal(dut, f'x{i}'):
                getattr(dut, f'x{i}').value = clamp_to_width(x_vals[i], DATA_WIDTH)
                getattr(dut, f'y{i}').value = clamp_to_width(y_vals[i], DATA_WIDTH)
            else:
                # Fallback to arrays if present
                dut.x[i].value = clamp_to_width(x_vals[i], DATA_WIDTH)
                dut.y[i].value = clamp_to_width(y_vals[i], DATA_WIDTH)
        else:
            # Set unused to 0
            if has_signal(dut, f'x{i}'):
                getattr(dut, f'x{i}').value = 0
                getattr(dut, f'y{i}').value = 0
            else:
                dut.x[i].value = 0
                dut.y[i].value = 0

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_convexity_cover(dut):
    """Test the convexity cover module with sample inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, list of (x,y), expected result)
    test_cases = [
        (4, [(0,0), (1,1), (1,0), (0,1)], 2),
        (8, [(0,0), (2,2), (0,2), (2,0), (1,0), (1,2), (0,1), (2,1)], 3),
        (3, [(0,0), (1,0), (0,1)], 2),  # triangle
    ]
    
    for i, (n, points, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: n={n}, expected={expected}")
        
        # Prepare x and y arrays
        x_vals = [p[0] for p in points]
        y_vals = [p[1] for p in points]
        
        # Write inputs
        await write_points(dut, n, x_vals, y_vals)
        
        # Assert start
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
    
    cocotb.log.info("All tests passed!")
