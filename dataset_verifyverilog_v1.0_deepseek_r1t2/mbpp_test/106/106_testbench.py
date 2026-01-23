import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
TUPLE_SIZE = 8
LIST_SIZE = 8
RESULT_SIZE = 16
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
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

async def write_array(dut, array_name, values, size, element_width):
    """Write values to array element by element."""
    # Get the array handle
    arr = getattr(dut, array_name)
    
    # Write each element individually
    for i in range(size):
        if i < len(values):
            arr[i].value = clamp_to_width(values[i], element_width)
        else:
            arr[i].value = 0

async def read_result_array(dut, size):
    """Read result array element by element."""
    results = []
    for i in range(size):
        if is_value_defined(dut.result_arr[i].value):
            results.append(int(dut.result_arr[i].value))
        else:
            results.append(None)
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_array_append(dut):
    """Test array append functionality."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (tuple_values, list_values, tuple_len, list_len, expected_result)
    test_cases = [
        # Test 1: tuple(9,10) + list(5,6,7) -> (9,10,5,6,7)
        ([9, 10], [5, 6, 7], 2, 3, [9, 10, 5, 6, 7]),
        
        # Test 2: tuple(10,11) + list(6,7,8) -> (10,11,6,7,8)
        ([10, 11], [6, 7, 8], 2, 3, [10, 11, 6, 7, 8]),
        
        # Test 3: tuple(11,12) + list(7,8,9) -> (11,12,7,8,9)
        ([11, 12], [7, 8, 9], 2, 3, [11, 12, 7, 8, 9]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (tuple_vals, list_vals, tuple_len, list_len, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: tuple_len={tuple_len}, list_len={list_len}")
        cocotb.log.info(f"  Tuple: {tuple_vals}, List: {list_vals}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write input arrays
            await write_array(dut, 'tuple_arr', tuple_vals, TUPLE_SIZE, DATA_WIDTH)
            await write_array(dut, 'list_arr', list_vals, LIST_SIZE, DATA_WIDTH)
            
            # Write lengths
            dut.tuple_len.value = tuple_len
            dut.list_len.value = list_len
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = await read_result_array(dut, RESULT_SIZE)
            
            # Verify first N elements match expected
            result_len = tuple_len + list_len
            actual = result[:result_len]
            
            cocotb.log.info(f"  Got: {actual}")
            
            if actual != expected:
                raise TestFailure(f"Expected {expected}, got {actual}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Edge case: single element each
    cocotb.log.info("\nEdge case: single elements")
    await write_array(dut, 'tuple_arr', [42], TUPLE_SIZE, DATA_WIDTH)
    await write_array(dut, 'list_arr', [99], LIST_SIZE, DATA_WIDTH)
    dut.tuple_len.value = 1
    dut.list_len.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = await read_result_array(dut, RESULT_SIZE)
    expected = [42, 99]
    
    if result[:2] != expected:
        raise TestFailure(f"Edge case failed: expected {expected}, got {result[:2]}")
    
    cocotb.log.info("  PASS")