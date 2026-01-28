import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

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

async def write_array(dut, values):
    """Write values to individual array ports."""
    for i in range(ARRAY_SIZE):
        if i < len(values):
            val = clamp_to_width(values[i], DATA_WIDTH)
        else:
            val = 0  # Pad with zeros
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = val
        else:
            # Fallback to indexed array
            dut.arr[i].value = val

async def read_result(dut):
    """Read result signal with validation."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return to_signed(int(dut.result.value), DATA_WIDTH)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_largest_non_square(dut):
    """Test the largest_non_square module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (inputs, expected_output, description)
    # Note: Input arrays are 8 elements, padded with zeros if needed
    test_cases = [
        ([4, 2, 0, 0, 0, 0, 0, 0], 2, "Sample 1: 4 is square, 2 is not"),
        ([1, 2, 4, 8, 16, 32, 64, 576], 32, "Sample 2: 32 is largest non-square"),
        ([-1, -4, -9, 0, 0, 0, 0, 0], -1, "All negatives: -1 is largest"),
        ([918375, 169764, 598796, 76602, 538757, 0, 0, 0], 918375, "Large numbers: 918375 is non-square"),
        ([999999, 1000000, 0, 0, 0, 0, 0, 0], 999999, "999999 is non-square, 1000000 is square"),
        ([0, -5, 0, 0, 0, 0, 0, 0], -5, "Zero and negative"),
        ([131073, 1, 0, 0, 0, 0, 0, 0], 131073, "Large non-square"),
        ([1, 1, -1, 0, 0, 0, 0, 0], -1, "Two 1's and -1"),
        ([2, 3, 4, 5, 0, 0, 0, 0], 5, "Small numbers: 5 is largest non-square"),
        ([-1000000, 1000000, 0, 0, 0, 0, 0, 0], -1000000, "Extreme values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inputs, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Inputs: {inputs}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write inputs
            await write_array(dut, inputs)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read and verify result
            result = await read_result(dut)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")