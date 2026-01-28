import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 1
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
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_array(dut, values, element_width):
    """Write values to arr[0:7]."""
    for i, val in enumerate(values):
        if i >= ARRAY_SIZE:
            break
        dut.arr[i].value = clamp_to_width(val, element_width)

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
async def test_check_element(dut):
    """Test the check_element module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # ASCII conversion helper for strings
    def ascii(val):
        if isinstance(val, str):
            return ord(val)
        return val
    
    # Define test cases: (array_values, element_value, length, expected_result, description)
    test_cases = [
        # Test 1: Strings that don't all match
        ([ascii('g'), ascii('o'), ascii('b'), ascii('w')], ascii('b'), 4, 0, "Some differ: green orange black white vs blue"),
        
        # Test 2: Numbers that don't match
        ([1, 2, 3, 4], 7, 4, 0, "Numbers: 1,2,3,4 vs 7"),
        
        # Test 3: All strings match
        ([ascii('g'), ascii('g'), ascii('g'), ascii('g')], ascii('g'), 4, 1, "All match: green green green green vs green"),
        
        # Additional test: Single element matching
        ([ascii('x')], ascii('x'), 1, 1, "Single element match"),
        
        # Additional test: Single element not matching
        ([ascii('a')], ascii('b'), 1, 0, "Single element differ"),
        
        # Additional test: Mixed with zeros
        ([0, 0, 0, 0], 0, 4, 1, "All zeros match"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, elem_val, length, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            await write_array(dut, arr_vals, DATA_WIDTH)
            dut.element.value = clamp_to_width(elem_val, DATA_WIDTH)
            dut.len.value = clamp_to_width(length, 4)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read and verify result
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
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")