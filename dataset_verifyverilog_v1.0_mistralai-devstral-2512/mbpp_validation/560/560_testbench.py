import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 8
OUTPUT_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    """Write individual values to an array signal."""
    for i in range(ARRAY_SIZE):
        if i < len(vals):
            v = vals[i]
        else:
            v = 0
        try:
            arr_elem = getattr(dut, name)[i]
            arr_elem.value = clamp_to_width(v, width)
        except AttributeError:
            # Try packed array format
            pass

async def read_result(dut):
    """Read result array from DUT."""
    result = []
    valid_mask = []
    
    # Try to read result array
    if has_signal(dut, 'result'):
        try:
            for i in range(OUTPUT_SIZE):
                if hasattr(dut.result, '__getitem__'):
                    val = safe_int(dut.result[i].value)
                else:
                    # Assume packed format
                    val = safe_int(dut.result.value) >> (8 * i) & 0xFF
                result.append(val)
        except Exception as e:
            # Fallback to packed result
            packed = safe_int(dut.result.value)
            for i in range(OUTPUT_SIZE):
                val = (packed >> (8 * i)) & 0xFF
                result.append(val)
    
    # Try to read valid mask
    if has_signal(dut, 'valid'):
        try:
            valid_mask_int = safe_int(dut.valid.value)
            valid_mask = [(valid_mask_int >> i) & 1 for i in range(OUTPUT_SIZE)]
        except:
            # Default: all valid
            valid_mask = [1] * OUTPUT_SIZE
    else:
        # Default: all valid
        valid_mask = [1] * OUTPUT_SIZE
    
    return result, valid_mask

def compute_union(arr1, arr2):
    """Compute expected union result."""
    combined = list(arr1) + list(arr2)
    unique_sorted = sorted(set(combined))
    return unique_sorted

def verify_result(computed, expected):
    """Verify computed result matches expected."""
    if len(computed) != len(expected):
        return False, f"Length mismatch: {len(computed)} vs {len(expected)}"
    for i, (c, e) in enumerate(zip(computed, expected)):
        if c != e:
            return False, f"Position {i}: expected {e}, got {c}"
    return True, "OK"

# Test cases
test_cases = [
    ([3, 4, 5, 6], [5, 7, 4, 10], [3, 4, 5, 6, 7, 10], "Test 1"),
    ([1, 2, 3, 4], [3, 4, 5, 6], [1, 2, 3, 4, 5, 6], "Test 2"),
    ([11, 12, 13, 14], [13, 15, 16, 17], [11, 12, 13, 14, 15, 16, 17], "Test 3"),
    ([], [], [], "Test 4: Empty"),
    ([5, 5, 5, 5], [5, 5, 5, 5], [5], "Test 5: All duplicates"),
    ([1, 3, 5, 7, 9, 11, 13, 15], [2, 4, 6, 8, 10, 12, 14, 16], [i for i in range(1, 17)], "Test 6: Full set"),
]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_union_elements(dut):
    """Test union of two tuples/arrays."""
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut, cycles=2)
    
    # Wait for initial state
    await Timer(50, units='ns')
    
    passed = 0
    failed = 0
    
    for i, (arr1_vals, arr2_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running {desc}: arr1={arr1_vals}, arr2={arr2_vals}")
        
        # Prepare inputs
        len1 = len(arr1_vals)
        len2 = len(arr2_vals)
        
        # Write arrays
        await write_array(dut, 'arr1', arr1_vals, DATA_WIDTH)
        await write_array(dut, 'arr2', arr2_vals, DATA_WIDTH)
        
        # Write lengths
        if has_signal(dut, 'len1'):
            dut.len1.value = len1
        if has_signal(dut, 'len2'):
            dut.len2.value = len2
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
        else:
            # Combinational - just wait a bit
            await Timer(100, units='ns')
        
        # Read result
        result, valid_mask = await read_result(dut)
        
        # Get actual values from valid mask
        computed = []
        for idx, is_valid in enumerate(valid_mask):
            if is_valid:
                computed.append(result[idx])
        
        # Read len_out if available
        if has_signal(dut, 'len_out'):
            len_out = int(dut.len_out.value)
            if len_out != len(computed):
                cocotb.log.warning(f"len_out mismatch: {len_out} vs {len(computed)}")
        
        # Verify
        success, msg = verify_result(computed, expected)
        if success:
            cocotb.log.info(f"PASS: {desc}")
            passed += 1
        else:
            cocotb.log.error(f"FAIL: {desc}: {msg}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")
