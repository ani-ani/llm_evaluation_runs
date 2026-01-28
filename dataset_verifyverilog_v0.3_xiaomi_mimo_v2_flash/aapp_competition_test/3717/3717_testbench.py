import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
ARRAY_SIZE = 16
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
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_rectangles(dut, rectangles, n):
    """Write rectangle coordinates to DUT."""
    for i in range(n):
        x1, y1, x2, y2 = rectangles[i]
        # Clamp values to 32-bit signed range
        x1 = clamp_to_width(x1, 32)
        y1 = clamp_to_width(y1, 32)
        x2 = clamp_to_width(x2, 32)
        y2 = clamp_to_width(y2, 32)
        
        # Assign to individual ports
        dut.x1[i].value = from_signed(x1, 32)
        dut.y1[i].value = from_signed(y1, 32)
        dut.x2[i].value = from_signed(x2, 32)
        dut.y2[i].value = from_signed(y2, 32)

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_common_point(dut):
    """Test find_common_point module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (rectangles, expected_x, expected_y, description)
    test_cases = [
        # Example 1
        ([(0, 0, 1, 1), (1, 1, 2, 2), (3, 0, 4, 1)], 1, 1, "First sample"),
        # Example 2  
        ([(0, 0, 1, 1), (0, 1, 1, 2), (1, 0, 2, 1)], 1, 1, "Second sample"),
        # Example 3
        ([(0, 0, 5, 5), (0, 0, 4, 4), (1, 1, 4, 4), (1, 1, 4, 4)], 1, 1, "Third sample"),
        # Example 4
        ([(0, 0, 10, 8), (1, 2, 6, 7), (2, 3, 5, 6), (3, 4, 4, 5), (8, 1, 9, 2)], 3, 4, "Fourth sample"),
        # Simple case - all rectangles contain (0,0)
        ([(0, 0, 1, 1), (0, 0, 2, 2), (-1, -1, 1, 1)], 0, 0, "All contain (0,0)"),
        # Case where removing one rectangle gives intersection
        ([(0, 0, 2, 2), (1, 1, 3, 3), (3, 3, 4, 4)], 1, 1, "Remove outlier"),
        # Large coordinates
        ([(1000000000, 1000000000, 1000000001, 1000000001),
          (999999999, 999999999, 1000000000, 1000000000)], 1000000000, 1000000000, "Large coordinates"),
        # Negative coordinates
        ([(-5, -5, -1, -1), (-3, -3, 0, 0)], -3, -3, "Negative coordinates"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (rectangles, exp_x, exp_y, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            n = len(rectangles)
            
            # Write inputs
            await write_rectangles(dut, rectangles, n)
            dut.n.value = n
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.result_x.value) or not is_value_defined(dut.result_y.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_x = to_signed(int(dut.result_x.value), 32)
            result_y = to_signed(int(dut.result_y.value), 32)
            
            # Verify result is in at least n-1 rectangles
            count = 0
            for x1, y1, x2, y2 in rectangles:
                if x1 <= result_x <= x2 and y1 <= result_y <= y2:
                    count += 1
            
            if count < n-1:
                raise TestFailure(f"Result ({result_x},{result_y}) is only in {count} of {n} rectangles")
            
            cocotb.log.info(f"  PASS: Found ({result_x},{result_y}) in {count}/{n} rectangles")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")