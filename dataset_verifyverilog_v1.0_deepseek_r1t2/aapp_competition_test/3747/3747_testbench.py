import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
RESULT_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_char_array(dut, values):
    """Write character values to the char_array."""
    for i, val in enumerate(values):
        if i < ARRAY_SIZE:
            dut.char_array[i].value = clamp_to_width(val, DATA_WIDTH)

async def read_result(dut):
    """Safely read result value."""
    if is_value_defined(dut.result.value):
        return int(dut.result.value)
    return 0

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
# TEST HELPER FUNCTIONS
# ============================================================================

def compute_expected(test_string):
    """Compute expected number of Bulbasaurs from a string."""
    # Count character frequencies
    count_B = test_string.count('B')
    count_u = test_string.count('u')
    count_l = test_string.count('l')
    count_b = test_string.count('b')
    count_a = test_string.count('a')
    count_s = test_string.count('s')
    count_r = test_string.count('r')
    
    # Each Bulbasaur requires: 1 B, 2 u, 1 l, 1 b, 2 a, 1 s, 1 r
    # So we can form at most:
    ans = min(
        count_B,
        count_u // 2,
        count_l,
        count_b,
        count_a // 2,
        count_s,
        count_r
    )
    return ans

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_count_bulbasaurs(dut):
    """Test the count_bulbasaurs module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_string, description)
    test_cases = [
        ("Bulbbasaur", "Bulbbasaur - should give 1"),
        ("F", "F - should give 0"),
        ("aBddulbasaurrgndgbualdBdsagaurrgndbb", "Example 3 - should give 2"),
        ("Bulbasaur", "Perfect Bulbasaur - should give 1"),
        ("BulbasaurBulbasaur", "Two perfect Bulbasaurs - should give 2"),
        ("B", "Only B - should give 0"),
        ("u", "Only u - should give 0"),
        ("uuaa", "Two u's and two a's - should give 0 (missing other letters)"),
        ("Bulbasau", "Missing r - should give 0"),
        ("BBBBBBBuuuuuuuullllllllllllbbbbaaaaaassssssssssssssssaaaaauuuuuuuuuuuuurrrrrrrrrrrrrrrr", "Many letters - should give many"),
        ("BBBBBBBBBBbbbbbbbbbbuuuuuuuuuullllllllllssssssssssaaaaaaaaaarrrrrrrrrr", "Balanced large counts - should give 5"),
        ("BBBBBBBBBBssssssssssssssssssssaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaarrrrrrrrrr", "Missing B and u - should give 0"),
        ("BBuuuullbbaassaarr", "Condensed test - should give 2"),
        ("BBuullbbaassaauurr", "Condensed test 2 - should give 2"),
        ("BBuuuullbbbbbbbbbbbbbbbaassrr", "More b's - should give 1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_string, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Truncate to maximum 16 characters
        truncated = test_string[:ARRAY_SIZE]
        valid_length = len(truncated)
        
        # Compute expected result
        expected = compute_expected(truncated)
        
        # Convert string to ASCII values
        char_values = [ord(c) for c in truncated]
        
        try:
            # Write inputs
            await write_char_array(dut, char_values)
            dut.valid_length.value = valid_length
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")