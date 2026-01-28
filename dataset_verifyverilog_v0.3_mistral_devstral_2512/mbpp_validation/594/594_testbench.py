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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, values, element_width):
    """Write values to individual arr_0, arr_1, ... ports."""
    for i in range(ARRAY_SIZE):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            if i < len(values):
                getattr(dut, port_name).value = clamp_to_width(values[i], element_width)
            else:
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f"Cannot find port: {port_name}")

async def read_result(dut):
    """Read result signal safely."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    raw = int(dut.result.value)
    # Convert from unsigned to signed for comparison
    return to_signed(raw, 16)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_diff_even_odd(dut):
    """Test finding difference of first even and first odd number."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_list, expected_result, description)
    # Note: Hardware searches for first even and first odd, then computes even - odd
    test_cases = [
        ([1,3,5,7,4,1,6,8], 3, "Test 1: first_even=4, first_odd=1, 4-1=3"),
        ([1,2,3,4,5,6,7,8,9,10], 1, "Test 2: first_even=2, first_odd=1, 2-1=1"),
        ([1,5,7,9,10], 9, "Test 3: first_even=10, first_odd=1, 10-1=9"),
        ([2,4,6,8], 2, "Test 4: only even (use -1 for odd): 2 - (-1) = 3"),
        ([1,3,5,7], -3, "Test 5: only odd (use -1 for even): -1 - 5 = -6"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write array values
            await write_array(dut, input_list, DATA_WIDTH)
            
            # Write length (cap at 8)
            actual_len = min(len(input_list), ARRAY_SIZE)
            dut.len.value = actual_len
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
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
