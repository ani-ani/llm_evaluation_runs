import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def wait_for_done(dut, max_cycles=1000):
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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, values):
    """Write values to individual array ports."""
    port_names = ['arr_0', 'arr_1', 'arr_2', 'arr_3', 'arr_4', 'arr_5', 'arr_6', 'arr_7']
    for i, val in enumerate(values):
        if i < len(port_names) and i < 8:  # Maximum 8 elements
            port = getattr(dut, port_names[i])
            port.value = clamp_to_width(val, 8)
    # Zero out remaining ports for safety
    for i in range(len(values), 8):
        port = getattr(dut, port_names[i])
        port.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dragon(dut):
    """Test the dragon module with various cases."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array, expected_result, description)
    test_cases = [
        ([1, 2, 1, 2], 4, "Example 1: [1,2,1,2] -> 4"),
        ([1, 1, 2, 2, 2, 1, 1, 2], 8, "Example 2 scaled to 8: [1,1,2,2,2,1,1,2] -> 8"),
        ([1, 1, 1, 1], 4, "All 1s"),
        ([2, 2, 2, 2], 4, "All 2s"),
        ([1, 2], 2, "Simple two elements"),
        ([2, 1], 2, "Reverse order"),
        ([1, 2, 2, 1], 3, "Mixed pattern"),
        ([2, 1, 1, 2], 4, "Full non-decreasing possible"),
        ([1, 1, 2, 2, 1, 1, 2, 2], 7, "Alternating blocks"),
        ([1, 2, 1, 2, 1, 2, 1, 2], 8, "Alternating single"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (array, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Skip tests with more than 8 elements
        if len(array) > 8:
            cocotb.log.warning(f"  Skipping - array length {len(array)} > 8")
            continue
        
        try:
            # Write array to DUT
            await write_array(dut, array)
            
            # Set n
            dut.n.value = len(array)
            
            # Start computation
            await start_computation(dut)
            
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
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")