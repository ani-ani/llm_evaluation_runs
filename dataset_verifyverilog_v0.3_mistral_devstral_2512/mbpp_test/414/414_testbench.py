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
MAX_CYCLES = 100
CLK_PERIOD_NS = 10

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
    if value < 0:
        return 0
    return min(max_val, max(0, value))

async def write_list(dut, list_name, values, element_width, length):
    """Write values to list and set length."""
    # Write array elements
    for i in range(ARRAY_SIZE):
        port_name = f"{list_name}_{i}"
        if has_signal(dut, port_name):
            if i < length:
                getattr(dut, port_name).value = clamp_to_width(values[i], element_width)
            else:
                getattr(dut, port_name).value = 0
        else:
            # Try indexed array
            try:
                arr = getattr(dut, list_name)
                if i < length:
                    arr[i].value = clamp_to_width(values[i], element_width)
                else:
                    arr[i].value = 0
            except AttributeError:
                raise TestFailure(f"Cannot find list {list_name} at index {i}")
    
    # Set length
    len_signal = getattr(dut, f"{list_name.replace('list', 'len')}")
    len_signal.value = length

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_overlapping(dut):
    """Test overlapping function."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (list1, list2, expected_result, description)
    test_cases = [
        ([1, 2, 3, 4, 5], [6, 7, 8, 9], 0, "No overlap"),
        ([1, 2, 3], [4, 5, 6], 0, "No overlap - small lists"),
        ([1, 4, 5], [1, 4, 5], 1, "Complete overlap"),
        ([10, 20, 30], [5, 10, 15], 1, "Partial overlap"),
        ([1, 2, 3], [], 0, "Empty second list"),
        ([], [1, 2, 3], 0, "Empty first list"),
        ([], [], 0, "Both empty"),
        ([255, 0, 127], [127, 64, 32], 1, "Edge values (255, 0, 127)"),
        ([1, 1, 1], [2, 2, 2], 0, "Duplicate values, no overlap"),
        ([5, 5, 5], [5, 5, 5], 1, "Duplicate values, all overlap"),
        ([1, 2, 3, 4, 5, 6, 7, 8], [8, 7, 6, 5, 4, 3, 2, 1], 1, "Full 8-element overlap"),
        ([1, 2, 3, 4, 5, 6, 7, 8], [9, 10, 11, 12, 13, 14, 15, 16], 0, "Full 8-element no overlap"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (list1, list2, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  list1: {list1}")
        cocotb.log.info(f"  list2: {list2}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write inputs
            len1 = len(list1)
            len2 = len(list2)
            
            await write_list(dut, 'list1', list1, DATA_WIDTH, len1)
            await write_list(dut, 'list2', list2, DATA_WIDTH, len2)
            
            # Wait one cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} ✓ PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
