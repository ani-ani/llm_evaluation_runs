import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000
NUM_STREAMS = 4

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_stream_scheduler(dut):
    """Test the stream scheduler with the given example."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test case: (s0,d0,p0), (s1,d1,p1), (s2,d2,p2), (s3,d3,p3), expected result
    # Example from problem: 4 streams
    # 1 3 6  -> s=1, d=3, p=6
    # 2 5 8  -> s=2, d=5, p=8
    # 3 3 5  -> s=3, d=3, p=5
    # 5 3 6  -> s=5, d=3, p=6
    # Expected output: 13
    
    s_vals = [1, 2, 3, 5]
    d_vals = [3, 5, 3, 3]
    p_vals = [6, 8, 5, 6]
    expected = 13
    
    # Feed inputs
    dut.s0.value = s_vals[0]
    dut.d0.value = d_vals[0]
    dut.p0.value = p_vals[0]
    
    dut.s1.value = s_vals[1]
    dut.d1.value = d_vals[1]
    dut.p1.value = p_vals[1]
    
    dut.s2.value = s_vals[2]
    dut.d2.value = d_vals[2]
    dut.p2.value = p_vals[2]
    
    dut.s3.value = s_vals[3]
    dut.d3.value = d_vals[3]
    dut.p3.value = p_vals[3]
    
    # Wait a few cycles for inputs to settle
    await Timer(50, units='ns')
    
    # Start computation
    await start_computation(dut)
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result = int(dut.result.value)
    
    # Verify
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    dut._log.info(f"Test PASSED: result = {result}")
    
    # Additional test case: all streams non-overlapping (should yield sum of all priorities)
    # Modify start times to be non-overlapping: s = [1,5,9,13], d=[3,3,3,3], p=[10,20,30,40]
    # Expected: 100
    
    s_vals2 = [1, 5, 9, 13]
    d_vals2 = [3, 3, 3, 3]
    p_vals2 = [10, 20, 30, 40]
    expected2 = 100
    
    dut.s0.value = s_vals2[0]
    dut.d0.value = d_vals2[0]
    dut.p0.value = p_vals2[0]
    dut.s1.value = s_vals2[1]
    dut.d1.value = d_vals2[1]
    dut.p1.value = p_vals2[1]
    dut.s2.value = s_vals2[2]
    dut.d2.value = d_vals2[2]
    dut.p2.value = p_vals2[2]
    dut.s3.value = s_vals2[3]
    dut.d3.value = d_vals2[3]
    dut.p3.value = p_vals2[3]
    
    await Timer(50, units='ns')
    await start_computation(dut)
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result2 = int(dut.result.value)
    
    if result2 != expected2:
        raise TestFailure(f"Expected {expected2}, got {result2}")
    
    dut._log.info(f"Test PASSED: result = {result2}")
    
    dut._log.info("All tests passed!")