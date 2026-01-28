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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

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

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

DATA_WIDTH = 32
ARRAY_SIZE = 16
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sound_compression(dut):
    """Test sound compression module with various scenarios."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.n.value = 0
    dut.I.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, I, input_array, expected_result, description)
    test_cases = [
        # Original examples
        (6, 1, [2, 1, 2, 3, 4, 3], 2, "First example: n=6, I=1 byte"),
        (6, 2, [2, 1, 2, 3, 4, 3], 0, "Second example: n=6, I=2 bytes"),
        (6, 1, [1, 1, 2, 2, 3, 3], 2, "Third example: n=6, I=1 byte"),
        
        # Edge cases
        (1, 100, [42], 0, "Single element, plenty of space"),
        (16, 1, list(range(16)), 15, "16 distinct values, I=1 byte"),
        (8, 1, [1, 1, 1, 1, 1, 1, 1, 1], 0, "All same, I=1 byte"),
        (8, 100, [1, 2, 3, 4, 5, 6, 7, 8], 0, "8 distinct, I=100 bytes"),
        (4, 1, [1, 2, 3, 4], 2, "4 distinct, I=1 byte"),
    ]
    
    for i, (n_val, I_val, input_arr, expected, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        dut._log.info(f"  Input: n={n_val}, I={I_val}, array={input_arr}")
        
        # Load data into module
        dut.start.value = 1
        dut.n.value = n_val
        dut.I.value = I_val
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed array elements one by one
        for j, val in enumerate(input_arr):
            dut.data_in.value = val
            await RisingEdge(dut.clk)
        
        # Wait for computation to complete
        timeout = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > MAX_CYCLES:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Read result
        if is_value_defined(dut.result.value):
            actual = int(dut.result.value)
        else:
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
        
        # Verify
        if actual != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {actual}")
        
        dut._log.info(f"  Result: {actual} [PASS]")
    
    dut._log.info("\n" + "="*50)
    dut._log.info("All tests passed successfully!")