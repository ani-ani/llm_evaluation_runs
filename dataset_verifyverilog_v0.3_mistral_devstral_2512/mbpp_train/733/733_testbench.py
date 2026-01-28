import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
INDEX_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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

async def write_array(dut, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        for i, val in enumerate(values):
            dut.arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            # Try MSB-first naming (arr_7, arr_6, ...)
            port_name_msb = f"arr_{ARRAY_SIZE-1-i}"
            if has_signal(dut, port_name_msb):
                getattr(dut, port_name_msb).value = clamp_to_width(val, element_width)
            else:
                raise TestFailure(f"Cannot find array port for index {i}")

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'target'):
        dut.target.value = 0
    
    for _ in range(2):
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

async def start_search(dut, target_val):
    """Start search with given target value."""
    dut.target.value = clamp_to_width(target_val, DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_first_occurrence(dut):
    """Test the find_first_occurrence module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array, target, expected_index, description)
    # Scaled to 8 elements max
    test_cases = [
        ([2, 5, 5, 5, 6, 6, 8, 9], 5, 1, "First occurrence at index 1"),
        ([2, 3, 5, 5, 6, 6, 8, 9], 5, 2, "First occurrence at index 2"),
        ([2, 4, 1, 5, 6, 6, 8, 9], 6, 4, "First occurrence at index 4"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 5, 4, "Single occurrence"),
        ([1, 1, 1, 2, 3, 4, 5, 6], 1, 0, "All same at beginning"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 0, 255, "Target not in array (too small)"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 9, 255, "Target not in array (too large)"),
        ([5, 5, 5, 5, 5, 5, 5, 5], 5, 0, "All elements match"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (array, target, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Array: {array}")
        cocotb.log.info(f"  Target: {target}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write array (must handle missing trailing elements)
            arr_full = array + [0] * (ARRAY_SIZE - len(array))
            await write_array(dut, arr_full, DATA_WIDTH)
            
            # Wait a cycle for array to settle
            await RisingEdge(dut.clk)
            
            # Start search
            await start_search(dut, target)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Validate result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST: Edge case - multiple identical values
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Edge case: array with duplicates, verify first occurrence
    cocotb.log.info("Testing edge case: multiple occurrences")
    
    array = [2, 5, 5, 5, 6, 6, 8, 9]
    target = 5
    expected = 1
    
    await write_array(dut, array, DATA_WIDTH)
    await RisingEdge(dut.clk)
    
    await start_search(dut, target)
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    
    if result != expected:
        raise TestFailure(f"Edge case failed: expected {expected}, got {result}")
    
    cocotb.log.info(f"Edge case passed: result = {result}")