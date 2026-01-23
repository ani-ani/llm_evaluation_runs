import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100
SENTINEL = 0xFF  # Represents non-integer values

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, values, element_width):
    """Write values to arr[0:7] array."""
    # Try 2D array access pattern
    try:
        arr = getattr(dut, 'arr')
        for i in range(ARRAY_SIZE):
            if i < len(values):
                arr[i].value = clamp_to_width(values[i], element_width)
            else:
                arr[i].value = 0
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(ARRAY_SIZE):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: arr[{i}] or {port_name}")

async def read_result(dut):
    """Safely read result signal."""
    if not is_value_defined(dut.result.value):
        return None
    return int(dut.result.value)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_filtered(dut):
    """Test max_filtered module with heterogeneous list adaptation."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (input_values, expected_output, description)
    # Sentinel 0xFF represents non-integer strings
    test_cases = [
        ([SENTINEL, 3, 2, 4, 5, SENTINEL], 5, "Python, 3, 2, 4, 5, version"),
        ([SENTINEL, 15, 20, 25], 25, "Python, 15, 20, 25"),
        ([SENTINEL, 30, 20, 40, 50, SENTINEL], 50, "Python, 30, 20, 40, 50, version"),
        ([SENTINEL, SENTINEL, SENTINEL], 0, "All sentinel values"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, "All integers 1-8"),
        ([0, 0, 0, 0, 0], 0, "All zeros"),
        ([100, 50, 200, 250, SENTINEL], 200, "Mixed with 200 max"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_vals, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {[hex(v) if v == SENTINEL else v for v in input_vals]}, Expected: {expected}")
        
        try:
            # Write inputs to array
            await write_array(dut, input_vals, DATA_WIDTH)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = len(input_vals)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read and verify result
            result = await read_result(dut)
            
            if result is None:
                raise TestFailure("Result is undefined (X/Z)")
            
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