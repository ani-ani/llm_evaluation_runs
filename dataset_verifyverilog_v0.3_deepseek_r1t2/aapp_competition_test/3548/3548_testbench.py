import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 8
MAX_PAIRS = 8
DATA_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================
async def write_pairs(dut, pairs, element_width=8):
    """Write pairs to pairs_packed vector."""
    packed = 0
    for i, (a, b) in enumerate(pairs):
        if i >= MAX_PAIRS:
            break
        # Pack as 8-bit: lower 4 bits a, upper 4 bits b
        packed |= ((a & 0xF) | ((b & 0xF) << 4)) << (8 * i)
    dut.pairs_packed.value = packed

async def write_inputs(dut, N, P, pairs):
    """Write N, P, and pairs."""
    dut.N.value = N
    dut.P.value = P
    await write_pairs(dut, pairs)

async def read_result(dut):
    """Read result and done."""
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
    return int(dut.result.value)

async def reset_dut(dut):
    """Reset DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_drink_partition_counter(dut):
    """Test the drink_partition_counter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # (N, P, pairs, expected_result)
        (5, 3, [(1,3), (4,5), (2,4)], 5),
        (5, 0, [], 16),
    ]
    
    for i, (N, P, pairs, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}: N={N}, P={P}, pairs={pairs}")
        
        # Write inputs
        await write_inputs(dut, N, P, pairs)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Read result
        result = await read_result(dut)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {i+1} failed: expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("All tests passed")