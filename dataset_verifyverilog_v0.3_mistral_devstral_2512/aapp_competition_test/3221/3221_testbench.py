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
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

MAX_M = 16
MAX_N = 8
DATA_WIDTH = 16
ALPHA_WIDTH = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000  # Maximum cycles for computation
SENTINEL = 0xFFFFFFFF

# ============================================================================
# HELPER FUNCTIONS FOR ARRAY ACCESS
# ============================================================================

async def write_edges(dut, u_list, v_list, c_list, valid_mask):
    """Write edge data to DUT ports."""
    for i in range(MAX_M):
        if has_signal(dut, f'u[{i}]'):
            if i < len(u_list):
                dut.u[i].value = clamp_to_width(u_list[i], 3)
            else:
                dut.u[i].value = 0
        if has_signal(dut, f'v[{i}]'):
            if i < len(v_list):
                dut.v[i].value = clamp_to_width(v_list[i], 3)
            else:
                dut.v[i].value = 0
        if has_signal(dut, f'c[{i}]'):
            if i < len(c_list):
                dut.c[i].value = clamp_to_width(c_list[i], DATA_WIDTH)
            else:
                dut.c[i].value = 0
    # Write valid mask
    if has_signal(dut, 'valid_edge'):
        dut.valid_edge.value = valid_mask

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ginger_candies(dut):
    """Test the ginger_candies module with several cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Each case: (M, u_list, v_list, c_list, valid_mask, alpha, expected)
    # expected is either an integer or "Poor" for sentinel
    test_cases = [
        # Case 1: Triangle with 3 edges
        (
            3,
            [0, 1, 2],
            [1, 2, 0],
            [10, 20, 30],
            0b111,
            5,
            30*30 + 5*3  # 900 + 15 = 915
        ),
        # Case 2: Single edge (no cycle)
        (
            1,
            [0],
            [1],
            [10],
            0b1,
            5,
            "Poor"
        ),
        # Case 3: Two separate triangles (like scaled sample 2)
        # Edges: (0,2,10), (2,4,30), (4,0,50), (1,3,20), (3,5,40), (5,1,60)
        (
            6,
            [0, 2, 4, 1, 3, 5],
            [2, 4, 0, 3, 5, 1],
            [10, 30, 50, 20, 40, 60],
            0b111111,
            7,
            50*50 + 7*3  # 2500 + 21 = 2521
        ),
        # Case 4: Square with 4 edges (simple cycle)
        (
            4,
            [0, 1, 2, 3],
            [1, 2, 3, 0],
            [10, 20, 30, 40],
            0b1111,
            5,
            40*40 + 5*4  # 1600 + 20 = 1620
        ),
    ]
    
    for i, (M, u_list, v_list, c_list, valid_mask, alpha, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}")
        
        # Write inputs
        await write_edges(dut, u_list, v_list, c_list, valid_mask)
        dut.M.value = clamp_to_width(M, 4)
        dut.alpha.value = clamp_to_width(alpha, ALPHA_WIDTH)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if expected == "Poor":
            if result != SENTINEL:
                raise TestFailure(f"Test {i+1}: expected Poor (0x{SENTINEL:08X}), got 0x{result:08X}")
        else:
            if result != expected:
                raise TestFailure(f"Test {i+1}: expected {expected}, got {result}")
        
        dut._log.info(f"Test {i+1}: PASS (result = {result})")
        
        # Prepare for next test: reset DUT again
        await reset_dut(dut)
    
    dut._log.info("All tests passed!")
