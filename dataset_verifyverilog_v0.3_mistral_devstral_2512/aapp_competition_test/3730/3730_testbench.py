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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, values, element_width):
    """Write values to array ports."""
    for i, val in enumerate(values):
        if i >= ARRAY_SIZE:
            break
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {port_name}")

async def read_result(dut):
    """Read result from DUT."""
    if is_value_defined(dut.result.value):
        return int(dut.result.value)
    else:
        raise TestFailure("Result is undefined (X/Z)")

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
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
# TEST LOGIC
# ============================================================================

def python_solution(arr, n):
    """Python reference solution for verification."""
    if n == 0:
        return 0
    left = [1] * n
    right = [1] * n
    
    for i in range(1, n):
        if arr[i] > arr[i-1]:
            left[i] = left[i-1] + 1
    
    for i in range(n-2, -1, -1):
        if arr[i] < arr[i+1]:
            right[i] = right[i+1] + 1
    
    ans = max(left) if n > 0 else 0
    
    for i in range(n):
        if i > 0:
            ans = max(ans, left[i-1] + 1)
        if i < n-1:
            ans = max(ans, right[i+1] + 1)
        if i > 0 and i < n-1:
            if arr[i-1] + 1 < arr[i+1]:
                ans = max(ans, left[i-1] + 1 + right[i+1])
    
    return ans

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_longest_subsegment(dut):
    """Main test function."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (array, len, expected_result, description)
    # We scale down the original examples to 8 elements max
    test_cases = [
        ([7, 2, 3, 1, 5, 6], 6, 5, "Original example"),
        ([1, 2, 3, 4, 5], 5, 5, "Already strictly increasing"),
        ([5, 4, 3, 2, 1], 5, 2, "Strictly decreasing"),
        ([1, 1, 1, 1, 1], 5, 2, "All equal"),
        ([1, 5, 2, 3, 4], 5, 5, "Change first element"),
        ([1, 2, 3, 5, 4], 5, 5, "Change last element"),
        ([1, 2, 5, 3, 4], 5, 5, "Change middle element"),
        ([1], 1, 1, "Single element"),
        ([1, 2], 2, 2, "Two elements"),
        ([1, 1], 2, 2, "Two equal elements"),
        ([1, 2, 2, 3, 4], 5, 5, "Duplicate in middle"),
        ([1, 2, 4, 5, 6], 5, 5, "Can extend by changing 3rd"),
        ([1, 3, 2, 4, 5], 5, 5, "Can change 2nd to 2"),
        ([10, 1, 2, 3, 4], 5, 5, "Change first to 0"),
        ([1, 2, 3, 4, 100], 5, 5, "Large jump at end"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, length, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {arr[:length]}, Expected: {expected}")
        
        try:
            # Write array
            await write_array(dut, arr, DATA_WIDTH)
            
            # Write length
            dut.len.value = length
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Test {i+1} failed: expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
