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

async def write_array(dut, values, element_width):
    """Write values to array ports arr_0 through arr_7."""
    for i in range(ARRAY_SIZE):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {port_name}")

async def read_array(dut, array_name, size):
    """Read array values from arr_0 through arr_7."""
    results = []
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

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

def find_sum_reference(arr):
    """Reference Python implementation."""
    arr = sorted(arr)
    if not arr:
        return 0
    total = arr[0]
    for i in range(len(arr)-1):
        if arr[i] != arr[i+1]:
            total += arr[i+1]
    return total

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_non_repeated_sum(dut):
    """Test the non-repeated elements summation module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_array, expected_sum, description)
    test_cases = [
        ([1, 2, 3, 1, 1, 4, 5, 6], 21, "Test 1: Mixed repeats"),
        ([1, 10, 9, 4, 2, 10, 10, 45, 4], 71, "Test 2: Multiple repeats"),
        ([12, 10, 9, 45, 2, 10, 10, 45, 10], 78, "Test 3: Complex repeats"),
        ([1, 1, 1, 1, 1, 1, 1, 1], 1, "Test 4: All same"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 36, "Test 5: All unique"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 0, "Test 6: All zeros"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_values, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Truncate or pad to exactly ARRAY_SIZE
            padded_input = input_values[:ARRAY_SIZE] + [0] * (ARRAY_SIZE - len(input_values[:ARRAY_SIZE]))
            
            # Write inputs to arr_0 through arr_7
            await write_array(dut, padded_input, DATA_WIDTH)
            
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
