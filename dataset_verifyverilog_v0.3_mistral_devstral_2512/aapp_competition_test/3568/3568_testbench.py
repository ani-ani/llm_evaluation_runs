import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'in_start'):
        dut.in_start.value = 0
    if has_signal(dut, 'in_valid'):
        dut.in_valid.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.in_start.value = 1
    await RisingEdge(dut.clk)
    dut.in_start.value = 0

async def send_value(dut, value):
    """Send a single value to the DUT."""
    dut.in_data.value = value
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

async def wait_for_done(dut, max_cycles=10000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.out_done.value) and int(dut.out_done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_movie_theme(dut):
    """Test the movie theme frequency checker."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: list of (input_data_sequence, expected_result)
    test_cases = [
        (
            [1, 6, 2, 0, 4, 6, 12],
            1,  # possible
            "One frequency, two intervals"
        ),
        (
            [1, 6, 3, 0, 5, 6, 8, 9, 14],
            0,  # impossible
            "One frequency, three intervals with gap issue"
        ),
        (
            [2, 6, 2, 0, 4, 6, 12, 10, 2, 0, 5, 8, 10],
            1,  # possible (both frequencies possible)
            "Two frequencies, both possible"
        )
    ]
    
    for test_idx, (data_seq, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {description}")
        
        # Start computation
        await start_computation(dut)
        
        # Send all data values
        for val in data_seq:
            await send_value(dut, val)
        
        # Wait for computation to complete
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.out_possible.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.out_possible.value)
        
        if result != expected:
            raise TestFailure(f"Test {test_idx+1} failed: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
        
        # Reset for next test
        await RisingEdge(dut.clk)
        await reset_dut(dut)
    
    cocotb.log.info("All tests passed!")
