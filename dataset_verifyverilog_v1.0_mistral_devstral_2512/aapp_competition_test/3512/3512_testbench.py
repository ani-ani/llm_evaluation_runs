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
MAX_N = 8
DATA_WIDTH = 12
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10

# ============================================================================
# HELPER FUNCTIONS FOR TESTBENCH
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

async def wait_for_done(dut, max_cycles=1000):
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

def set_weights(dut, N, weights):
    """Set the weight matrix for given N."""
    for i in range(N):
        for j in range(N):
            # Clamp to width for safety
            w_val = clamp_to_width(weights[i][j], DATA_WIDTH)
            dut.w[i][j].value = w_val

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_path(dut):
    """Test the min_path module with sample cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (N, weights_matrix, expected_result)
    test_cases = [
        # Sample 1: N=3
        (3, [
            [0, 5, 2],
            [5, 0, 4],
            [2, 4, 0]
        ], 7),
        # Sample 2: N=4
        (4, [
            [0, 15, 7, 8],
            [15, 0, 16, 9],
            [7, 16, 0, 12],
            [8, 9, 12, 0]
        ], 31),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (N, weights, expected) in enumerate(test_cases):
        dut._log.info(f"Test {test_idx+1}: N={N}, expected={expected}")
        
        # Set N
        dut.N.value = N
        
        # Set weight matrix
        set_weights(dut, N, weights)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            dut._log.error(f"Test {test_idx+1} FAILED: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {test_idx+1} PASSED")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
