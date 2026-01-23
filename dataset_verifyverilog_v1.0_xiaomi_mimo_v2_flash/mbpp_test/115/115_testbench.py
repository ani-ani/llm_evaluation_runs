import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_DICTS = 8
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_dict_flags(dut, dict_list):
    """Convert list of dictionaries to byte flags and write to array.
    0x00 = empty dict, 0x01 = non-empty dict"""
    flags = []
    for d in dict_list:
        # In Python: {} is empty (False), {1,2} is non-empty (True)
        # We encode: 0x00 for empty, 0x01 for non-empty
        if isinstance(d, dict):
            flags.append(0x01 if len(d) > 0 else 0x00)
        elif isinstance(d, set):
            # Handle Test 2: {1,2} is a set, not dict, but treated as non-empty
            flags.append(0x01 if len(d) > 0 else 0x00)
        else:
            # Should not happen
            flags.append(0x00)
    
    # Write flags to dut.dict_flags array
    for i in range(min(len(flags), MAX_DICTS)):
        dut.dict_flags[i].value = clamp_to_width(flags[i], DATA_WIDTH)
    
    # Write num_dicts
    dut.num_dicts.value = clamp_to_width(len(flags), 4)

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
async def test_empty_dict_check(dut):
    """Test the empty_dict_check module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (dict_list, expected_result, description)
    # Note: Test 2 has {1,2} which is a set in Python, but we treat as non-empty
    test_cases = [
        ([{}, {}, {}], True, "All empty dicts"),           # Test 1
        ([{1, 2}, {}, {}], False, "One non-empty dict"),   # Test 2 (set, but non-empty)
        ([{}], True, "Single empty dict"),                 # Test 3 (modified)
        ([{}, {1:2}, {}], False, "One non-empty dict (key-value)"),
        ([{1:2}, {3:4}, {5:6}], False, "All non-empty dicts"),
        ([{}, {}, {}, {}, {}, {}, {}, {}], True, "Eight empty dicts"),
        ([{}, {}, {1:2}], False, "Last dict non-empty"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (dict_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {dict_list}")
        
        try:
            # Write inputs
            await write_dict_flags(dut, dict_list)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read and verify result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            expected_int = 1 if expected else 0
            
            if result != expected_int:
                raise TestFailure(f"Expected {expected_int} ({expected}), got {result}")
            
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