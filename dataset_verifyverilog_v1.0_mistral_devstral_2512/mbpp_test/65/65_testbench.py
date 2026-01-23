import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
DEPTH_WIDTH = 2
MAX_ELEMENTS = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'valid_in'):
        dut.valid_in.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout, handling X/Z values."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

# ============================================================================
# FLATTENING HELPER
# ============================================================================

def flatten_list_structure(nested_list):
    """Convert nested list to sequence of (value, depth) tuples."""
    result = []
    
    def process_element(elem, current_depth):
        if isinstance(elem, list):
            for sub_elem in elem:
                process_element(sub_elem, current_depth + 1)
        else:
            result.append((elem, current_depth))
    
    # Start with top-level depth = 1
    for item in nested_list:
        process_element(item, 1)
    
    return result

async def send_nested_list(dut, nested_list):
    """Send a nested list structure to the DUT."""
    sequence = flatten_list_structure(nested_list)
    
    for value, depth in sequence:
        dut.data_in.value = clamp_to_width(value, DATA_WIDTH)
        dut.depth_in.value = depth
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    # End of sequence
    dut.valid_in.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_recursive_list_sum(dut):
    """Test the recursive list sum flattener."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Verify ready state
    if not is_value_defined(dut.ready.value) or int(dut.ready.value) != 1:
        raise TestFailure("DUT not ready after reset")
    
    # Define test cases
    test_cases = [
        ([1, 2, [3, 4], [5, 6]], 21, "Test 1: [1,2,[3,4],[5,6]]"),
        ([7, 10, [15, 14], [19, 41]], 106, "Test 2: [7,10,[15,14],[19,41]]"),
        ([10, 20, [30, 40], [50, 60]], 210, "Test 3: [10,20,[30,40],[50,60]]"),
        ([[1]], 1, "Test 4: [[1]] - nested single"),
        ([5], 5, "Test 5: [5] - single element"),
        ([[1, 2], [3, 4]], 10, "Test 6: [[1,2],[3,4]] - double nested"),
        ([1, [2, [3, 4], 5], 6], 21, "Test 7: [1,[2,[3,4],5],6] - triple depth"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (nested_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Check ready state
            if not is_value_defined(dut.ready.value) or int(dut.ready.value) != 1:
                raise TestFailure("DUT not ready before start")
            
            # Start computation
            await start_computation(dut)
            
            # Send nested list
            await send_nested_list(dut, nested_list)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=100)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
            # Wait for ready to be high again before next test
            await RisingEdge(dut.clk)
            timeout = 0
            while not (is_value_defined(dut.ready.value) and int(dut.ready.value) == 1):
                await RisingEdge(dut.clk)
                timeout += 1
                if timeout > 50:
                    raise TestFailure("DUT did not return to ready state")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")