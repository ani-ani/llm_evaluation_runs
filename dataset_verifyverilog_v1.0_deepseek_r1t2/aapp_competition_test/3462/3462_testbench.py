import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_LEN = 16
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.pattern_valid.value = 0
    dut.filename_valid.value = 0
    dut.pattern_end.value = 0
    dut.filename_end.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def feed_pattern(dut, pattern):
    """Feed pattern characters to DUT."""
    for i, char in enumerate(pattern):
        dut.pattern_char.value = ord(char)
        dut.pattern_valid.value = 1
        await RisingEdge(dut.clk)
    
    # Signal end of pattern
    dut.pattern_valid.value = 0
    dut.pattern_end.value = 1
    await RisingEdge(dut.clk)
    dut.pattern_end.value = 0

async def feed_filename(dut, filename):
    """Feed filename characters to DUT."""
    for i, char in enumerate(filename):
        dut.filename_char.value = ord(char)
        dut.filename_valid.value = 1
        await RisingEdge(dut.clk)
    
    # Signal end of filename
    dut.filename_valid.value = 0
    dut.filename_end.value = 1
    await RisingEdge(dut.clk)
    dut.filename_end.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def check_match(dut, expected_match):
    """Check if the match result is correct."""
    await RisingEdge(dut.clk)
    if not is_value_defined(dut.match.value):
        raise TestFailure("Match signal is undefined (X/Z)")
    
    actual_match = int(dut.match.value)
    if actual_match != expected_match:
        raise TestFailure(f"Expected match={expected_match}, got {actual_match}")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_file_matcher(dut):
    """Test the file matcher module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (pattern, filename, expected_match, description)
    test_cases = [
        ("*.*", "main.c", True, "Wildcard pattern with dot"),
        ("*.*", "a.out", True, "Wildcard pattern with dot"),
        ("*.*", "readme", False, "Wildcard pattern no dot"),
        ("*.*", "yacc", False, "Wildcard pattern no dot"),
        ("*.c", "main.c", True, "Extension match"),
        ("*.c", "main.h", False, "Extension mismatch"),
        ("main.*", "main.c", True, "Base match"),
        ("main.*", "test.c", False, "Base mismatch"),
        ("*a*a*a", "aaa", True, "Multiple wildcards"),
        ("*a*a*a", "aaaaa", True, "Multiple wildcards"),
        ("*a*a*a", "aaaaax", False, "Multiple wildcards mismatch"),
        ("*a*a*a", "abababa", True, "Multiple wildcards complex"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (pattern, filename, expected_match, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Pattern: '{pattern}', Filename: '{filename}'")
        
        try:
            # Reset for each test
            await reset_dut(dut)
            
            # Start the test
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed pattern and filename
            cocotb.start_soon(feed_pattern(dut, pattern))
            await feed_filename(dut, filename)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check match result
            await check_match(dut, expected_match)
            
            cocotb.log.info(f"  PASS: Match = {expected_match}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")