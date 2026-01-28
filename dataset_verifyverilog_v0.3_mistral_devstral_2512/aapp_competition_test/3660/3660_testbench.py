import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
MSG_LEN = 8
NUM_STICKERS = 4
STICKER_MAX_LEN = 4
PRICE_WIDTH = 20
CHAR_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

async def write_message(dut, message_str):
    """Write message to DUT, padding/truncating to MSG_LEN."""
    # Pad or truncate message
    padded = message_str.ljust(MSG_LEN, ' ')[:MSG_LEN]
    
    # Write each character
    for i, char in enumerate(padded):
        dut.msg[i].value = ord(char) if char != ' ' else 0

async def write_stickers(dut, stickers):
    """Write sticker definitions to DUT."""
    # stickers is list of (word, price) tuples
    for i, (word, price) in enumerate(stickers[:NUM_STICKERS]):
        # Pad/truncate word
        padded_word = word.ljust(STICKER_MAX_LEN, ' ')[:STICKER_MAX_LEN]
        
        # Write characters
        for j, char in enumerate(padded_word):
            dut.sticker_word[i][j].value = ord(char) if char != ' ' else 0
        
        # Write length
        dut.sticker_len[i].value = len(word)
        
        # Write price
        dut.sticker_price[i].value = price

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST CASES
# ============================================================================

def pack_test_cases():
    """Define test cases as (message, stickers, expected_cost or 'IMPOSSIBLE')."""
    return [
        (
            "BUYSTICKERS",
            [
                ("BUYER", 10),
                ("STICKY", 10),
                ("TICKERS", 1),
                ("ERS", 8)
            ],
            28
        ),
        (
            "ABBBA",
            [
                ("AAAAA", 10),
                ("BB", 3)
            ],
            "IMPOSSIBLE"
        ),
        # Additional test case for verification
        (
            "ABCD",
            [
                ("AB", 5),
                ("CD", 5),
                ("ABC", 8),
                ("BCD", 8)
            ],
            10  # AB + CD = 10 (cheaper than ABC + BCD = 16)
        )
    ]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sticker_cover(dut):
    """Main test for sticker covering module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Get test cases
    test_cases = pack_test_cases()
    
    passed = 0
    failed = 0
    
    for test_idx, (message, stickers, expected) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {test_idx + 1}: Message='{message}', Stickers={len(stickers)}")
        
        # Write inputs
        await write_message(dut, message)
        await write_stickers(dut, stickers)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read results
        if not is_value_defined(dut.possible.value):
            cocotb.log.error("  FAIL: possible signal is undefined (X/Z)")
            failed += 1
            continue
        
        possible = int(dut.possible.value)
        cost = int(dut.min_cost.value)
        
        # Verify
        if expected == "IMPOSSIBLE":
            if possible:
                cocotb.log.error(f"  FAIL: Expected IMPOSSIBLE, got cost={cost}")
                failed += 1
            else:
                cocotb.log.info(f"  PASS: Correctly reported IMPOSSIBLE")
                passed += 1
        else:
            if not possible:
                cocotb.log.error(f"  FAIL: Expected cost={expected}, got IMPOSSIBLE")
                failed += 1
            elif cost != expected:
                cocotb.log.error(f"  FAIL: Expected cost={expected}, got {cost}")
                failed += 1
            else:
                cocotb.log.info(f"  PASS: cost={cost}")
                passed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_reset_behavior(dut):
    """Test that reset properly initializes the module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Apply reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Check reset state
    if is_value_defined(dut.done.value) and int(dut.done.value) != 0:
        raise TestFailure("Reset failed: done should be 0")
    
    if is_value_defined(dut.possible.value) and int(dut.possible.value) != 0:
        raise TestFailure("Reset failed: possible should be 0")
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Verify idle state
    if is_value_defined(dut.done.value) and int(dut.done.value) != 0:
        raise TestFailure("Post-reset: done should be 0")
    
    cocotb.log.info("Reset behavior test passed")

@cocotb.test(timeout_time=3000, timeout_unit="ms")
async def test_boundary_conditions(dut):
    """Test edge cases and boundary conditions."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test 1: Single character message
    cocotb.log.info("Test 1: Single character message")
    await write_message(dut, "A")
    await write_stickers(dut, [("A", 5)])
    await start_computation(dut)
    await wait_for_done(dut)
    
    if not int(dut.possible.value):
        raise TestFailure("Should be possible to cover single char")
    if int(dut.min_cost.value) != 5:
        raise TestFailure(f"Expected cost 5, got {int(dut.min_cost.value)}")
    
    cocotb.log.info("  PASS")
    
    # Test 2: Exact sticker length match
    cocotb.log.info("Test 2: Exact length match")
    await reset_dut(dut)
    await write_message(dut, "ABCD")
    await write_stickers(dut, [("ABCD", 15)])
    await start_computation(dut)
    await wait_for_done(dut)
    
    if not int(dut.possible.value):
        raise TestFailure("Should be possible")
    if int(dut.min_cost.value) != 15:
        raise TestFailure(f"Expected cost 15, got {int(dut.min_cost.value)}")
    
    cocotb.log.info("  PASS")
    
    # Test 3: No stickers
    cocotb.log.info("Test 3: No stickers")
    await reset_dut(dut)
    await write_message(dut, "ABCD")
    await write_stickers(dut, [])
    await start_computation(dut)
    await wait_for_done(dut)
    
    if int(dut.possible.value):
        raise TestFailure("Should be impossible with no stickers")
    
    cocotb.log.info("  PASS")
    
    cocotb.log.info("All boundary tests passed")