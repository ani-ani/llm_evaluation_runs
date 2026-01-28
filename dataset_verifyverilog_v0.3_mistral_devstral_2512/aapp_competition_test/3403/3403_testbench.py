import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
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

async def write_packed_array(dut, array_name, values, element_bits=8):
    """Pack values into single integer and assign to signal."""
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    getattr(dut, array_name).value = result

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
# TEST CASE SCALING
# ============================================================================

# Scale down database to 8 words, 8 characters each
scaled_database = [
    "majmunica"[:8].ljust(8, '\x00'),  # "majmunic"
    "majmun"[:8].ljust(8, '\x00'),    # "majmun\x00\x00"
    "majka"[:8].ljust(8, '\x00'),     # "majka\x00\x00\x00"
    "malina"[:8].ljust(8, '\x00'),    # "malina\x00\x00"
    "malinska"[:8].ljust(8, '\x00'),  # "malinska"
    "malo"[:8].ljust(8, '\x00'),     # "malo\x00\x00\x00\x00"
    "maleni"[:8].ljust(8, '\x00'),   # "maleni\x00\x00"
    "malesnica"[:8].ljust(8, '\x00'), # "malesnic"
]

# Scaled queries (first 3 from second sample)
scaled_queries = [
    "krampus"[:8].ljust(8, '\x00'),
    "malnar"[:8].ljust(8, '\x00'),
    "majmun"[:8].ljust(8, '\x00'),
]

# Expected results for scaled queries
expected_results = [
    8,   # krampus: 8 words compared, 0 total LCP
    29,  # malnar: 8 words compared, 21 total LCP  
    16,  # majmun: 2 words compared, 14 total LCP (6+8)
]

def string_to_bits(s):
    """Convert 8-character string to 64-bit integer."""
    result = 0
    for i, char in enumerate(s[:8]):
        result |= ord(char) << (i * 8)
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_word_search(dut):
    """Test the word search module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Initialize database memory
    dut._log.info("Initializing database memory...")
    for i, word in enumerate(scaled_database):
        bits = string_to_bits(word)
        dut.database[i].value = bits
        dut._log.info(f"  database[{i}] = {word!r} = 0x{bits:016x}")
    
    # Wait a few cycles for memory initialization
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    # Test each query
    for i, (query_str, expected) in enumerate(zip(scaled_queries, expected_results)):
        dut._log.info(f"\nTest {i+1}: Query '{query_str}'")
        
        # Convert query to packed format
        query_bits = string_to_bits(query_str)
        dut.query_word.value = query_bits
        dut._log.info(f"  Query bits: 0x{query_bits:016x}")
        
        # Start computation
        await start_computation(dut)
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        dut._log.info(f"  Result: {result} [PASS]")
    
    dut._log.info("\n" + "="*50)
    dut._log.info("All tests passed!")
    dut._log.info("="*50)
