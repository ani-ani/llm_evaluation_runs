import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
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
# ARRAY HELPERS
# ============================================================================

async def write_strengths(dut, strengths, max_len=8):
    """Write strengths to the input array."""
    # Ensure we don't exceed the array size
    strengths = strengths[:max_len]
    
    # Individual element assignment
    for i, s in enumerate(strengths):
        dut.strengths[i].value = clamp_to_width(s, DATA_WIDTH)
    
    # Set remaining elements to 0 if needed
    for i in range(len(strengths), max_len):
        dut.strengths[i].value = 0

async def read_result(dut):
    """Read the result signal."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_min_piles(dut):
    """Test the find_min_piles module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, strengths_list, expected_piles, description)
    test_cases = [
        (3, [0, 0, 10], 2, "Example 1: 3 boxes"),
        (5, [0, 1, 2, 3, 4], 1, "Example 2: 5 boxes"),
        (4, [0, 0, 0, 0], 4, "Example 3: 4 zeros"),
        (9, [0, 1, 0, 2, 0, 1, 1, 2, 10], 3, "Example 4: 9 boxes"),
        (1, [0], 1, "Single box"),
        (2, [0, 0], 2, "Two zeros"),
        (2, [0, 1], 1, "Two boxes: 0 and 1"),
        (2, [100, 99], 1, "High strengths"),
        (5, [4, 1, 1, 1, 1], 2, "Additional test case"),
        (8, [0, 1, 1, 0, 2, 0, 3, 45], 3, "8 boxes mixed"),
        (8, [1, 1, 1, 2, 2, 2, 2, 2], 4, "Multiple 1s and 2s")
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, strengths, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: n={n}, strengths={strengths}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write inputs
            await write_strengths(dut, strengths)
            dut.n.value = n
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
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
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")