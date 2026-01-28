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
# TESTBENCH CONFIGURATION
# ============================================================================

DATA_WIDTH = 21      # Width for coefficients and coordinates
RESULT_WIDTH = 9     # Width for count (max 300)
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000   # Enough for 300 lines * ~30 cycles each

# Pack line coefficients into 63-bit memory word
async def write_line(dut, address, a, b, c):
    """Write one line to memory."""
    # Clamp values to 21-bit signed range
    a_val = clamp_to_width(a, DATA_WIDTH)
    b_val = clamp_to_width(b, DATA_WIDTH)
    c_val = clamp_to_width(c, DATA_WIDTH)
    
    # Pack into 63-bit word: {a[20:0], b[20:0], c[20:0]}
    packed = (a_val << 42) | (b_val << 21) | c_val
    
    # Write to memory
    dut.wr_addr.value = address
    dut.wr_data.value = packed
    dut.wr_en.value = 1
    await RisingEdge(dut.clk)
    dut.wr_en.value = 0

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.wr_en.value = 0
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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_crazy_town(dut):
    """Main test function for Crazy Town problem."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (x1, y1, x2, y2, lines, expected_count)
    # Lines are list of tuples (a, b, c)
    test_cases = [
        # Example 1: 2 lines, both separate the points
        (1, 1, -1, -1, 
         [(0, 1, 0), (1, 0, 0)],
         2),
        
        # Example 2: 3 lines, 2 separate the points
        (1, 1, -1, -1,
         [(1, 0, 0), (0, 1, 0), (1, 1, -3)],
         2),
        
        # Additional test: points on same side of all lines
        (0, 0, 1, 1,
         [(1, 0, -5), (0, 1, -5), (1, 1, -10)],
         0),
        
        # Additional test: points on opposite sides of one line
        (0, 0, 10, 10,
         [(1, 1, -5)],  # Line x+y=5 separates them
         1),
        
        # Additional test: single line, not separating
        (0, 0, 1, 1,
         [(1, 1, 10)],  # Both points on same side
         0),
    ]
    
    for i, (x1, y1, x2, y2, lines, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: x1={x1}, y1={y1}, x2={x2}, y2={y2}, lines={lines}")
        
        # Write all lines to memory
        for addr, (a, b, c) in enumerate(lines):
            await write_line(dut, addr, a, b, c)
        
        # Set coordinates and number of lines
        dut.x1.value = clamp_to_width(x1, DATA_WIDTH)
        dut.y1.value = clamp_to_width(y1, DATA_WIDTH)
        dut.x2.value = clamp_to_width(x2, DATA_WIDTH)
        dut.y2.value = clamp_to_width(y2, DATA_WIDTH)
        dut.n.value = len(lines)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.count.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
        
        result = int(dut.count.value)
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
        
        # Wait a bit before next test
        await Timer(100, units='ns')
        await reset_dut(dut)
    
    cocotb.log.info("="*50)
    cocotb.log.info("All tests passed!")