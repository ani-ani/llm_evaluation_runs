import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
COORD_WIDTH = 10
RESULT_WIDTH = 32
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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_goat_rope(dut):
    """Test goat rope module for n=2 and n=3."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, [x0,y0,x1,y1,x2,y2], expected_result_100, description)
    test_cases = [
        (
            2,
            [250, 250, 250, 750],
            50000,
            "Two posts 500 apart"
        ),
        (
            3,
            [250, 250, 500, 500, 250, 750],
            60355,
            "Three posts"
        ),
        (
            2,
            [0, 0, 1000, 1000],
            141421,
            "Maximum range diagonal"
        ),
        (
            3,
            [0, 0, 100, 0, 0, 100],
            34142,
            "Small right triangle"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, coords, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Assign coordinates based on n
            # Always assign all ports (some may be unused)
            if len(coords) >= 4:
                dut.x0.value = clamp_to_width(coords[0], COORD_WIDTH)
                dut.y0.value = clamp_to_width(coords[1], COORD_WIDTH)
                dut.x1.value = clamp_to_width(coords[2], COORD_WIDTH)
                dut.y1.value = clamp_to_width(coords[3], COORD_WIDTH)
            if len(coords) >= 6:
                dut.x2.value = clamp_to_width(coords[4], COORD_WIDTH)
                dut.y2.value = clamp_to_width(coords[5], COORD_WIDTH)
            else:
                # Set to zero for unused ports
                dut.x2.value = 0
                dut.y2.value = 0
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Allow small rounding error (1 unit in result*100)
            if abs(result - expected) > 1:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result/100:.2f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
