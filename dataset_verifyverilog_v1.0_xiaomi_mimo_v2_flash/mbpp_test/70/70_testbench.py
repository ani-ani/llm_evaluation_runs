import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
TUPLE_LEN_WIDTH = 4
NUM_TUPLES = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_equal_tuples(dut):
    """Test if all tuples have equal length."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (tuple_lengths, expected_result, description)
    # Each test case: list of lengths for tuples
    test_cases = [
        ([3, 3, 3, 3], 1, "All equal length (3,3,3,3)"),
        ([2, 3, 2, 2], 0, "Mismatch (2,3,2,2)"),
        ([1, 1], 1, "Two tuples equal (1,1)"),
        ([4, 4, 4, 4, 4, 4, 4, 4], 1, "8 tuples all equal (4,4,4,4,4,4,4,4)"),
        ([5, 5, 5, 5, 5, 5, 5, 6], 0, "8 tuples, last mismatch (5,5,5,5,5,5,5,6)"),
        ([7], 1, "Single tuple (7)"),
        ([], 1, "Empty tuple list"),
        ([2, 2, 0, 0], 1, "Mixed with zeros (2,2,0,0)"),
        ([3, 3, 3, 2], 0, "Three equal, last different (3,3,3,2)"),
        ([8, 8, 8, 8], 1, "Max length (8,8,8,8)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (tuple_lengths, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Determine number of valid tuples
            num_tuples = len(tuple_lengths)
            
            # Set individual length inputs
            # Initialize all to 0 first
            for j in range(NUM_TUPLES):
                port_name = f"tuple_len_{j}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = 0
            
            # Set actual values
            for j, length in enumerate(tuple_lengths):
                if j < NUM_TUPLES:
                    port_name = f"tuple_len_{j}"
                    if has_signal(dut, port_name):
                        clamped_length = clamp_to_width(length, TUPLE_LEN_WIDTH)
                        getattr(dut, port_name).value = clamped_length
            
            # Set number of tuples
            if has_signal(dut, 'num_tuples'):
                dut.num_tuples.value = clamp_to_width(num_tuples, 4)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
