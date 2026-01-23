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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TEST CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    """Main test function."""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (num_cities, K, list of (x,y,pop), expected_sq_dist)
    test_cases = [
        (3, 3, [(0,4,4), (1,5,1), (2,6,1)], 2),
        (6, 11, [(0,0,1), (0,1,2), (1,0,3), (1,1,4), (5,5,1), (20,20,10)], 32),
        (6, 5, [(20,20,9), (0,0,3), (0,1,1), (10,0,1), (10,1,6), (12,0,3)], 4),
    ]
    
    for tc in test_cases:
        num_cities, K, cities, expected_sq = tc
        dut._log.info(f"Testing: N={num_cities}, K={K}, expected sq={expected_sq}")
        
        # Set inputs
        dut.num_cities.value = num_cities
        dut.K.value = K
        
        # Assign city data (ports x0..x3, y0..y3, pop0..pop3)
        # For simplicity, assign only first num_cities cities; others 0
        for i in range(4):
            if i < num_cities:
                x, y, pop = cities[i]
                getattr(dut, f'x{i}').value = x
                getattr(dut, f'y{i}').value = y
                getattr(dut, f'pop{i}').value = pop
            else:
                getattr(dut, f'x{i}').value = 0
                getattr(dut, f'y{i}').value = 0
                getattr(dut, f'pop{i}').value = 0
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read result
        result = int(dut.sq_dist_result.value)
        
        # Verify
        if result != expected_sq:
            raise TestFailure(f"Expected {expected_sq}, got {result}")
        else:
            dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("All tests passed")