import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_SUBLISTS = 8
MAX_SUBLEN = 8
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
    dut.data_in.value = 0
    dut.valid_in.value = 0
    dut.end_of_sublist.value = 0
    dut.end_of_input.value = 0
    
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

async def feed_sublist(dut, sublist):
    """Feed a single sublist to the DUT."""
    for i, val in enumerate(sublist):
        dut.data_in.value = clamp_to_width(val, DATA_WIDTH)
        dut.valid_in.value = 1
        dut.end_of_sublist.value = 1 if (i == len(sublist) - 1) else 0
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    dut.end_of_sublist.value = 0
    await RisingEdge(dut.clk)

async def feed_data(dut, input_2d):
    """Feed 2D array to DUT one element at a time."""
    for i, sublist in enumerate(input_2d):
        is_last_sublist = (i == len(input_2d) - 1)
        
        for j, val in enumerate(sublist):
            # Set data
            dut.data_in.value = clamp_to_width(val, DATA_WIDTH)
            dut.valid_in.value = 1
            
            # Flags
            is_last_element = (j == len(sublist) - 1)
            dut.end_of_sublist.value = 1 if is_last_element else 0
            dut.end_of_input.value = 1 if (is_last_sublist and is_last_element) else 0
            
            await RisingEdge(dut.clk)
        
        # Clear valid after sublist ends
        dut.valid_in.value = 0
        dut.end_of_sublist.value = 0
        await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_sublist_length(dut):
    """Test the max_sublist_length module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_2d, expected_max_length, description)
    test_cases = [
        ([[1], [1,4], [5,6,7,8]], 4, "Test 1: Sublists with lengths 1,2,4"),
        ([[0,1], [2,2], [3,2,1]], 3, "Test 2: Sublists with lengths 2,2,3"),
        ([[7], [22,23], [13,14,15], [10,20,30,40,50]], 5, "Test 3: Sublists with lengths 1,2,3,5"),
        ([[1,2,3]], 3, "Single sublist"),
        ([[1],[1],[1]], 1, "All single elements"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_2d, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_2d}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed data
            await feed_data(dut, input_2d)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.max_length.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.max_length.value)
            cocotb.log.info(f"  Result: {result}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Status: PASS")
            passed += 1
            
            # Small delay between tests
            await Timer(100, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"  Status: FAIL - {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
