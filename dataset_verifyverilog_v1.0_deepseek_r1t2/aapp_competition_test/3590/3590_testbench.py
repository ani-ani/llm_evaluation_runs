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
DATA_WIDTH = 16
RESULT_WIDTH = 32
MAX_VERTICES = 8
CLK_PERIOD_NS = 10

# ============================================================================
# TEST CASES
# ============================================================================
# TC1: a=4, b=4
TC1_A = [
    (0, 0), (0, 14), (15, 14), (15, 0)
]
TC1_B = [
    (8, 3), (4, 6), (7, 10), (11, 7)
]
TC1_EXPECTED = 40.0

# TC2: a=4, b=8
TC2_A = [
    (-100, -100), (-100, 100), (100, 100), (100, -100)
]
TC2_B = [
    (-1, -2), (-2, -1), (-2, 1), (-1, 2),
    (1, 2), (2, 1), (2, -1), (1, -2)
]
TC2_EXPECTED = 322.1421356237

# ============================================================================
# HELPER TO SET INPUT ARRAYS
# ============================================================================

async def set_polygon(dut, prefix, vertices):
    """Set polygon vertices on DUT (prefix 'A' or 'B')."""
    n = len(vertices)
    # Set count
    if prefix == 'A':
        dut.a_cnt.value = n
    else:
        dut.b_cnt.value = n
    
    # Fill arrays (max MAX_VERTICES)
    for i in range(MAX_VERTICES):
        if i < n:
            x, y = vertices[i]
            # Convert to fixed-point (Q16.0) using from_signed for negative values
            x_fp = from_signed(x, DATA_WIDTH)
            y_fp = from_signed(y, DATA_WIDTH)
        else:
            x_fp = 0
            y_fp = 0
        
        # Assign using getattr to handle array indexing
        getattr(dut, f'{prefix}_vertices_x')[i].value = x_fp
        getattr(dut, f'{prefix}_vertices_y')[i].value = y_fp

# ============================================================================
# RESET SEQUENCE
# ============================================================================

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_polygon_cutter(dut):
    """Test PolygonCutter with the two provided examples."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1
    dut._log.info("Running Test Case 1")
    await set_polygon(dut, 'A', TC1_A)
    await set_polygon(dut, 'B', TC1_B)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await RisingEdge(dut.clk)  # At least one cycle
    for _ in range(100):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Done not asserted within 100 cycles")
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
    
    result_fp = int(dut.result.value)
    result_float = result_fp / (1 << 16)
    
    if abs(result_float - TC1_EXPECTED) > 1e-6:
        raise TestFailure(f"TC1: Expected {TC1_EXPECTED}, got {result_float}")
    
    dut._log.info(f"TC1 PASS: result = {result_float}")
    
    # Reset for next test
    await reset_dut(dut)
    
    # Test case 2
    dut._log.info("Running Test Case 2")
    await set_polygon(dut, 'A', TC2_A)
    await set_polygon(dut, 'B', TC2_B)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await RisingEdge(dut.clk)
    for _ in range(100):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Done not asserted within 100 cycles")
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
    
    result_fp = int(dut.result.value)
    result_float = result_fp / (1 << 16)
    
    if abs(result_float - TC2_EXPECTED) > 1e-6:
        raise TestFailure(f"TC2: Expected {TC2_EXPECTED}, got {result_float}")
    
    dut._log.info(f"TC2 PASS: result = {result_float}")
    
    dut._log.info("All tests passed!")
