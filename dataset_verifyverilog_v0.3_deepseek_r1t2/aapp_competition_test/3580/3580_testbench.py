import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 4
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
# ARRAY WRITE HELPER
# ============================================================================

async def write_array(dut, values):
    """Write values to the 8-element array."""
    # Ensure we have exactly 8 values
    if len(values) > 8:
        values = values[:8]
    elif len(values) < 8:
        values = values + [0] * (8 - len(values))
    
    # Write each element individually
    for i, val in enumerate(values):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Port arr_{i} not found")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_longest_subsequence(dut):
    """Test the find_longest_subsequence module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (sequence, start_index, set_B, expected_length, description)
    test_cases = [
        # Example from problem - padded to 8 elements
        ([1, 2, 3, 1, 2, 1, 1, 0], 0, [1, 2, 3], 7, "Original example, index 1, B={1,2,3}"),
        ([1, 2, 3, 1, 2, 1, 1, 0], 0, [1, 2], 2, "Original example, index 1, B={1,2}"),
        ([1, 2, 3, 1, 2, 1, 1, 0], 1, [2, 3], 2, "Original example, index 2, B={2,3}"),
        ([1, 2, 3, 1, 2, 1, 1, 0], 2, [1, 2], 0, "Original example, index 3, B={1,2}"),
        ([1, 2, 3, 1, 2, 1, 1, 0], 3, [1, 2], 4, "Original example, index 4, B={1,2}"),
        
        # Additional test cases
        ([5, 6, 7, 8, 9, 10, 11, 12], 0, [5, 6, 7], 3, "Higher numbers"),
        ([1, 1, 1, 1, 1, 1, 1, 1], 0, [1], 8, "All same, matching"),
        ([1, 1, 1, 2, 1, 1, 1, 1], 0, [1], 3, "Break at index 3"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 0, [0], 8, "All zeros"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 4, [5, 6, 7], 3, "Mid sequence start"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (sequence, start_index, set_B, expected_length, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Sequence: {sequence}")
        cocotb.log.info(f"  Start index: {start_index}, Set B: {set_B}")
        
        try:
            # Write sequence to array
            await write_array(dut, sequence)
            
            # Write start index (3-bit)
            dut.start_index.value = start_index
            
            # Write set B (up to 4 elements, pad with 0 if needed)
            b_values = set_B[:4] + [0] * (4 - len(set_B))
            dut.b0.value = clamp_to_width(b_values[0], DATA_WIDTH)
            dut.b1.value = clamp_to_width(b_values[1], DATA_WIDTH)
            dut.b2.value = clamp_to_width(b_values[2], DATA_WIDTH)
            dut.b3.value = clamp_to_width(b_values[3], DATA_WIDTH)
            
            # Write m (number of valid elements in B)
            dut.m.value = len(set_B)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.length.value):
                raise TestFailure("Result length is undefined (X/Z)")
            
            result = int(dut.length.value)
            
            # Verify result
            if result != expected_length:
                raise TestFailure(f"Expected {expected_length}, got {result}")
            
            cocotb.log.info(f"  PASS: length = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")