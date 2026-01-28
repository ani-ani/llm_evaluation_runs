import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
LEN_WIDTH = 3  # 0-7 values
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_input_array(dut, values, element_width=DATA_WIDTH):
    """Write values to input array arr[0:7]."""
    for i in range(ARRAY_SIZE):
        if i < len(values):
            dut.arr[i].value = clamp_to_width(values[i], element_width)
        else:
            dut.arr[i].value = 0

async def read_output_array(dut, size):
    """Read output array result[0:7]."""
    results = []
    for i in range(ARRAY_SIZE):
        if i < size and is_value_defined(dut.result[i].value):
            results.append(int(dut.result[i].value))
        else:
            results.append(0)  # Fill unused with 0
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    if has_signal(dut, 'arr'):
        for i in range(ARRAY_SIZE):
            dut.arr[i].value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST FUNCTION
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_even_filter(dut):
    """Test even number filtering functionality."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_array, input_len, expected_result, expected_output_len, description)
    test_cases = [
        ([1, 2, 3, 4, 5], 5, [2, 4], 2, "Basic: [1,2,3,4,5] -> [2,4]"),
        ([4, 5, 6, 7, 8, 0, 1], 7, [4, 6, 8, 0], 4, "Mixed with zero: [4,5,6,7,8,0,1] -> [4,6,8,0]"),
        ([8, 12, 15, 19], 4, [8, 12], 2, "All evens first: [8,12,15,19] -> [8,12]"),
        ([1, 3, 5, 7], 4, [], 0, "All odd numbers: [1,3,5,7] -> []"),
        ([2, 4, 6, 8, 10, 12, 14, 16], 8, [2, 4, 6, 8, 10, 12, 14, 16], 8, "All even: full array"),
        ([0], 1, [0], 1, "Single zero: [0] -> [0]"),
        ([255], 1, [], 0, "Single odd 255: []"),
        ([254], 1, [254], 1, "Single even 254: [254]"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, input_len, expected_result, expected_len, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Write inputs
            await write_input_array(dut, input_arr, DATA_WIDTH)
            dut.len.value = input_len
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read outputs
            if not is_value_defined(dut.output_len.value):
                raise TestFailure("output_len is undefined (X/Z)")
            
            actual_len = int(dut.output_len.value)
            
            if actual_len != expected_len:
                raise TestFailure(f"output_len mismatch: expected {expected_len}, got {actual_len}")
            
            # Read result array
            actual_result = []
            for j in range(actual_len):
                if not is_value_defined(dut.result[j].value):
                    raise TestFailure(f"result[{j}] is undefined")
                actual_result.append(int(dut.result[j].value))
            
            # Verify results
            if actual_result != expected_result:
                raise TestFailure(f"Result mismatch: expected {expected_result}, got {actual_result}")
            
            cocotb.log.info(f"  PASS: Found {actual_len} evens: {actual_result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")