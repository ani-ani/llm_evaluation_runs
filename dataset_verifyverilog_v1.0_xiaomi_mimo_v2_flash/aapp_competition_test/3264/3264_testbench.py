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
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 4       # N is up to 8, so 4 bits
RESULT_WIDTH = 30    # Result is 30 bits
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000   # Enough for up to 21*128+overhead cycles

# ============================================================================
# RESET HELPER
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_mirko_slavko(dut):
    """Test the mirko_slavko module for N=2,3,4."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (2, 1),  # N=2, answer=1
        (3, 5),  # N=3, answer=5
        (4, 21), # N=4, answer=21
    ]
    
    for N, expected in test_cases:
        dut._log.info(f"Testing N={N}, expecting {expected}")
        
        # Set N and pulse start
        dut.N.value = N
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done for N={N}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for N={N}")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"N={N}: expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info("All tests passed!")
