import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# COMPUTATION HELPERS (Python reference)
# ============================================================================

def is_inside_triangle(p, a, b, c):
    """Check if point p is strictly inside triangle a,b,c (clockwise)."""
    def cross(o, p1, p2):
        return (p1[0]-o[0])*(p2[1]-o[1]) - (p1[1]-o[1])*(p2[0]-o[0])
    return cross(a, b, p) < 0 and cross(b, c, p) < 0 and cross(c, a, p) < 0

def max_onions_contiguous(onions, fences):
    """Compute maximum onions protected by any contiguous triple of fence posts."""
    M = len(fences)
    N = len(onions)
    max_count = 0
    for s in range(M):
        a = fences[s]
        b = fences[(s+1) % M]
        c = fences[(s+2) % M]
        count = 0
        for p in onions:
            if is_inside_triangle(p, a, b, c):
                count += 1
        if count > max_count:
            max_count = count
    return max_count

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_onions(dut):
    """Test the max_onions_protected module with sample and custom cases."""
    
    # Configuration
    DATA_WIDTH = 8
    N = 5
    M = 5
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        {
            "name": "sample",
            "onions": [(1,1), (2,2), (1,3), (0,0), (0,0)],
            "fences": [(0,0), (0,3), (1,4), (3,3), (3,0)],
        },
        {
            "name": "custom",
            "onions": [(1,2), (2,2), (3,2), (4,2), (2,3)],
            "fences": [(0,0), (0,3), (2,5), (5,3), (5,0)],
        }
    ]
    
    for tc in test_cases:
        dut._log.info(f"Testing {tc['name']}")
        
        # Compute expected result using Python reference
        expected = max_onions_contiguous(tc['onions'], tc['fences'])
        dut._log.info(f"  Expected: {expected}")
        
        # Set onions
        for i, (x, y) in enumerate(tc['onions']):
            setattr(dut, f'onion{i}_x', x)
            setattr(dut, f'onion{i}_y', y)
        
        # Set fences
        for i, (x, y) in enumerate(tc['fences']):
            setattr(dut, f'fence{i}_x', x)
            setattr(dut, f'fence{i}_y', y)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result = int(dut.max_onions.value)
        dut._log.info(f"  Result: {result}")
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {tc['name']}: expected {expected}, got {result}")
        
        # Clear inputs (optional)
        # No need, next test will overwrite
    
    dut._log.info("All tests passed!")