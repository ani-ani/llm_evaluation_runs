import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
MAX_CYCLES = 100
CLK_PERIOD_NS = 10

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array_individual(dut, values, element_width, prefix="arr"):
    """Write values to individual array ports (arr_0, arr_1, ...)."""
    for i, val in enumerate(values):
        port_name = f"{prefix}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find port: {port_name}")

async def write_array_packed(dut, values, element_width, signal_name="arr"):
    """Write values to packed array signal."""
    packed_val = 0
    for i, val in enumerate(values):
        packed_val |= (clamp_to_width(val, element_width) & ((1 << element_width) - 1)) << (i * element_width)
    getattr(dut, signal_name).value = packed_val

async def read_array_individual(dut, size, prefix="out"):
    """Read values from individual output ports (out_0, out_1, ...)."""
    results = []
    for i in range(size):
        port_name = f"{prefix}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_remove_odd(dut):
    """Test remove_odd module."""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    has_len = has_signal(dut, 'len')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    else:
        # Combinational - wait for initial propagation
        await Timer(100, units='ns')
    
    # Test cases: (input_array, input_len, expected_output, expected_len, description)
    test_cases = [
        ([1, 2, 3, 0, 0, 0, 0, 0], 3, [2], 1, "Remove odd from [1,2,3]"),
        ([2, 4, 6, 0, 0, 0, 0, 0], 3, [2, 4, 6], 3, "All even [2,4,6]"),
        ([10, 20, 3, 0, 0, 0, 0, 0], 3, [10, 20], 2, "Mixed [10,20,3]"),
        ([1, 3, 5, 7, 0, 0, 0, 0], 4, [], 0, "All odd"),
        ([2, 4, 8, 16, 32, 64, 128, 1], 8, [2, 4, 8, 16, 32, 64, 128], 7, "Full array with last odd"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, in_len, expected_out, expected_len, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            await write_array_individual(dut, input_arr, DATA_WIDTH, "arr")
            
            if is_sequential:
                if has_len:
                    dut.len.value = in_len
                # Start computation
                await start_computation(dut)
                # Wait for completion
                await wait_for_done(dut)
                # Read out_len
                if has_signal(dut, 'out_len'):
                    actual_len = int(dut.out_len.value)
                else:
                    actual_len = in_len
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
                actual_len = in_len
            
            # Read output array
            actual_out = await read_array_individual(dut, ARRAY_SIZE, "out")
            
            # Truncate to actual_len and remove None values
            actual_out_filtered = [x for x in actual_out[:actual_len] if x is not None]
            
            # Verify length
            if is_sequential and has_signal(dut, 'out_len'):
                if actual_len != expected_len:
                    raise TestFailure(f"Length mismatch: expected {expected_len}, got {actual_len}")
            
            # Verify contents
            if actual_out_filtered != expected_out:
                raise TestFailure(f"Output mismatch: expected {expected_out}, got {actual_out_filtered}")
            
            cocotb.log.info(f"  PASS: output = {actual_out_filtered}, length = {actual_len}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")