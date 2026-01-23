import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8      # For counts
ARRAY_SIZE = 8      # Max number of inhabitants
MAX_N = 8
MAX_D = 16
MAX_R = 8
CLK_PERIOD_NS = 10
NUM_TRIALS = 1024   # Number of Monte Carlo trials per test case
TOLERANCE = 0.15    # Allowed absolute error

# ============================================================================
# HELPER FUNCTIONS
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
# TEST HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def run_trial(dut, n, d, r):
    """Run one trial of the simulation and return the sum of top r."""
    # Set inputs
    dut.n.value = n
    dut.d.value = d
    dut.r.value = r
    
    # Start pulse
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 10000
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined when done is asserted")
            return int(dut.result.value)
    
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=60000, timeout_unit="ms")
async def test_gem_island(dut):
    """Test the GemIslandSim module with Monte Carlo simulation."""
    
    # Detect signals
    has_clk = has_signal(dut, 'clk')
    has_rst_n = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_n = has_signal(dut, 'n')
    has_d = has_signal(dut, 'd')
    has_r = has_signal(dut, 'r')
    has_result = has_signal(dut, 'result')
    has_done = has_signal(dut, 'done')
    
    if not all([has_clk, has_rst_n, has_start, has_n, has_d, has_r, has_result, has_done]):
        raise TestFailure("Missing required signals: clk, rst_n, start, n, d, r, result, done")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, d, r, expected)
    test_cases = [
        (2, 3, 1, 3.5),
        (3, 3, 2, 4.9),
        (5, 10, 3, 12.2567433),
    ]
    
    for n, d, r, expected in test_cases:
        cocotb.log.info(f"Testing n={n}, d={d}, r={r}, expected={expected}")
        
        # Run multiple trials
        total_sum = 0
        for trial in range(NUM_TRIALS):
            # Run one trial
            trial_sum = await run_trial(dut, n, d, r)
            total_sum += trial_sum
            # Small delay between trials
            await Timer(10, units='ns')
        
        average = total_sum / NUM_TRIALS
        error = abs(average - expected)
        rel_error = error / expected if expected != 0 else error
        
        cocotb.log.info(f"  Trials: {NUM_TRIALS}, Average: {average:.6f}, Expected: {expected:.6f}, Error: {error:.6f}")
        
        if error > TOLERANCE and rel_error > 0.01:  # Allow 1% relative error or 0.15 absolute
            raise TestFailure(f"Average {average} differs from expected {expected} by {error}")
    
    cocotb.log.info("All tests passed!")