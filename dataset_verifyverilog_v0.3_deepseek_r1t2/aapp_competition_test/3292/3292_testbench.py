import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Match the HDL design parameters
# ============================================================================
MAX_NAMES = 8
MAX_LEN = 8
CHAR_WIDTH = 5  # Bits per character (A-Z -> 1-26, 0 = end)
DATA_WIDTH = CHAR_WIDTH
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
MOD = 1000000007

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
# ARRAY ACCESS HELPERS
# ============================================================================
async def write_names(dut, names):
    """Write names into the DUT's 2D array. Each name is a list of character codes."""
    # names is a list of lists, each inner list length MAX_LEN, padded with 0
    for i in range(len(names)):
        for j in range(MAX_LEN):
            dut.names[i][j].value = clamp_to_width(names[i][j], CHAR_WIDTH)

async def read_result(dut):
    """Read the result signal."""
    if is_value_defined(dut.result.value):
        return int(dut.result.value)
    else:
        raise TestFailure("Result is undefined (X/Z)")

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Standard reset sequence for active-low reset."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# TEST CASES
# ============================================================================
# Each test case: (N, list_of_names, expected_output)
# Names are given as strings; we will convert to character codes (A=1, B=2, ..., Z=26)
# We pad with 0 to MAX_LEN.

def string_to_codes(s):
    """Convert string to list of character codes (1-26), padded with 0."""
    codes = [ord(c) - ord('A') + 1 for c in s]  # A=1, B=2, ...
    while len(codes) < MAX_LEN:
        codes.append(0)
    return codes[:MAX_LEN]

# Sample test cases from problem (adapted to scale)
# Note: The original N up to 3000 is reduced to 8, so we use the same names but only up to 8.
# For demonstration, we use the provided examples.
test_cases = [
    (3, ["IVO", "JASNA", "JOSIPA"], 4),
    (5, ["MARICA", "MARTA", "MATO", "MARA", "MARTINA"], 24),
    (4, ["A", "AA", "AAA", "AAAA"], 8),
]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_name_ranking_counter(dut):
    """Main test function for NameRankingCounter."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for idx, (N, names_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nRunning Test Case {idx+1}: N={N}, Names={names_str}")
        
        # Convert names to character codes
        names_codes = [string_to_codes(s) for s in names_str]
        
        # Load names into DUT
        dut.num_names.value = N
        await write_names(dut, names_codes)
        
        # Clear any pending start
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} failed: {e}")
            failed += 1
            continue
        
        # Read result
        result = await read_result(dut)
        
        # Compare
        if result == expected:
            cocotb.log.info(f"Test {idx+1} PASS: result={result}")
            passed += 1
        else:
            cocotb.log.error(f"Test {idx+1} FAIL: expected {expected}, got {result}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST CASES (if needed)
# ============================================================================
# For completeness, we can add a test with 8 random names, but the above
# already covers the required samples.
