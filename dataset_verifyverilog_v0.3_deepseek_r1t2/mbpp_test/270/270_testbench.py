import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array_values(dut, values):
    """Write values to the 8 individual array ports."""
    # Ensure we have exactly 8 values, pad with 0 if needed
    padded_values = values + [0] * (8 - len(values))
    
    for i in range(8):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            val = clamp_to_width(padded_values[i], DATA_WIDTH)
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f"Signal {port_name} not found in DUT")

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
async def test_sum_even_even_pos(dut):
    """Main test function for sum_even_even_pos module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_list, expected_output, description)
    test_cases = [
        ([5, 6, 12, 1, 18, 8], 30, "Test 1: [5, 6, 12, 1, 18, 8] -> 30"),
        ([3, 20, 17, 9, 2, 10, 18, 13, 6, 18], 26, "Test 2: [3, 20, 17, 9, 2, 10, 18, 13, 6, 18] -> 26"),
        ([5, 6, 12, 1], 12, "Test 3: [5, 6, 12, 1] -> 12"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs to array ports
            await write_array_values(dut, input_list)
            
            # Set length
            dut.len.value = len(input_list)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read and verify result
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
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
