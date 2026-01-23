import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 4
RESULT_WIDTH = 4
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
    # Handle signed values for array elements
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
async def test_pos_counter(dut):
    """Test positive number counter."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (array_values, length, expected_count, description)
    test_cases = [
        ([1, -2, 3, -4], 4, 2, "Mixed positive and negative"),
        ([3, 4, 5, -1], 4, 3, "Three positives, one negative"),
        ([1, 2, 3, 4], 4, 4, "All positive"),
        ([0, 0, 1, -1], 4, 3, "Include zero (>= 0)"),
        ([-5, -10, -15, -20], 4, 0, "All negative"),
        ([10, 20, 0, 0], 4, 4, "Zeros count as positive"),
        ([1, 2, 3, 4], 2, 2, "Partial array (length=2)"),
        ([1, -2, 3, -4], 1, 1, "Single element (positive)"),
        ([-5, 10, -3, 2], 3, 1, "Partial array with mixed values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (values, length, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {values[:length]}, Expected: {expected}")
        
        try:
            # Write array elements individually
            for j in range(ARRAY_SIZE):
                if j < len(values):
                    val = clamp_to_width(values[j], DATA_WIDTH)
                    # Check if signal exists as individual port
                    port_name = f"arr_{j}"
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = val
                    else:
                        # Fallback to indexed array
                        dut.arr[j].value = val
                else:
                    # Default values for unused elements
                    port_name = f"arr_{j}"
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = 0
                    else:
                        dut.arr[j].value = 0
            
            # Write length
            if has_signal(dut, 'len'):
                dut.len.value = length
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
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