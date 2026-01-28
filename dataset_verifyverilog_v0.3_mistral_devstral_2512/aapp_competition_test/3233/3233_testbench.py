import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 6
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
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY HELPERS
# ============================================================================

def pack_array(values, element_bits=8, size=8):
    """Pack list of values into single integer, LSB first."""
    result = 0
    for i in range(size):
        val = values[i] if i < len(values) else 0
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

# ============================================================================
# SEQUENTIAL HELPERS
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
async def test_scary_subarrays(dut):
    """Test the scary_subarrays module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, values_list, expected_result, description)
    test_cases = [
        (5, [1, 2, 3, 4, 5], 5, "Sorted array n=5"),
        (6, [3, 2, 1, 6, 4, 5], 8, "Example 2 n=6"),
        (7, [2, 1, 5, 3, 6, 7, 4], 11, "Example 3 n=7"),
        (1, [1], 1, "Single element"),
        (2, [1, 2], 2, "Two elements"),
        (3, [2, 1, 3], 4, "Three elements"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, values, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  n={n}, values={values}, expected={expected}")
        
        try:
            # Pack array
            packed = pack_array(values, DATA_WIDTH, ARRAY_SIZE)
            cocotb.log.info(f"  Packed array: 0x{packed:016X}")
            
            # Write inputs
            dut.packed_arr.value = packed
            dut.n.value = n
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
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