import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_STRING_LEN = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# ASCII values
ASCII_A = 0x61
ASCII_B = 0x62

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

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'char_valid'):
        dut.char_valid.value = 0
    
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
# STRING MATCHING HELPER
# ============================================================================

async def test_string_match(dut, test_str, expected_match):
    """
    Feed string character by character and verify result.
    
    Args:
        dut: Device under test
        test_str: String to test
        expected_match: Expected match result (True/False)
    """
    # Reset before each test
    await reset_dut(dut)
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed characters
    for i, char in enumerate(test_str):
        # Set character
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        
        # Set str_end if last character
        dut.str_end.value = 1 if i == len(test_str) - 1 else 0
        
        await RisingEdge(dut.clk)
        
        # Deassert valid after cycle
        dut.char_valid.value = 0
        dut.str_end.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read match result
    if not is_value_defined(dut.match.value):
        raise TestFailure(f"Match signal is undefined (X/Z)")
    
    actual_match = int(dut.match.value) == 1
    
    if actual_match != expected_match:
        raise TestFailure(
            f"String '{test_str}': expected match={expected_match}, got {actual_match}"
        )
    
    return actual_match

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pattern_matcher(dut):
    """Test the pattern matcher with various strings."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Wait for clock to stabilize
    await Timer(50, units='ns')
    
    # Test cases: (string, expected_match, description)
    test_cases = [
        ("aabbbb", True, "Multiple b's after a"),
        ("aabAbbbc", False, "Uppercase A in middle"),
        ("accddbbjjj", False, "No 'a' character"),
        ("ab", True, "Minimal pattern"),
        ("a", False, "No ending 'b'"),
        ("b", False, "No 'a' at all"),
        ("aaabbb", True, "Multiple a's before first a"),
        ("abab", True, "Pattern appears at start"),
        ("xyzab", True, "Pattern at end"),
        ("xayb", True, "Pattern with characters between"),
        ("", False, "Empty string"),
        ("a" * 15 + "b", True, "Long string (16 chars)"),
        ("a" * 16, False, "Long string without b"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}/{len(test_cases)}: {description}")
        cocotb.log.info(f"  Input: '{test_str}'")
        
        try:
            result = await test_string_match(dut, test_str, expected)
            cocotb.log.info(f"  PASS: match={result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Additional edge case: Character after 'b' should still match
    cocotb.log.info(f"\nEdge case: String with 'b' not at end")
    try:
        await reset_dut(dut)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed "abx" - should NOT match because b is not at end
        for i, char in enumerate("abx"):
            dut.char_in.value = ord(char)
            dut.char_valid.value = 1
            dut.str_end.value = 1 if i == 2 else 0
            await RisingEdge(dut.clk)
            dut.char_valid.value = 0
            dut.str_end.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.match.value):
            raise TestFailure("Match signal undefined")
        
        if int(dut.match.value) == 1:
            cocotb.log.error("  FAIL: Should not match 'abx' (b not at end)")
            failed += 1
        else:
            cocotb.log.info("  PASS: Correctly rejects 'abx'")
            passed += 1
            
    except TestFailure as e:
        cocotb.log.error(f"  FAIL: {e}")
        failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_state_transitions(dut):
    """Test FSM state transitions are correct."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await Timer(50, units='ns')
    
    await reset_dut(dut)
    
    # Test: find 'a', then 'b' as last char
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Characters: 'x', 'y', 'a', 'z', 'b'
    chars = ['x', 'y', 'a', 'z', 'b']
    for i, char in enumerate(chars):
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        dut.str_end.value = 1 if i == len(chars) - 1 else 0
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        dut.str_end.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.match.value):
        raise TestFailure("Match signal undefined")
    
    if int(dut.match.value) == 1:
        cocotb.log.info("State transition test: PASS")
    else:
        raise TestFailure("State transition test: FAIL")
