import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
COLOR_MAP = {'R': 0, 'G': 1, 'B': 2, 'Y': 3, 'W': 4}
VALUE_MAP = {'1': 0, '2': 1, '3': 2, '4': 3, '5': 4}

# Helper functions
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def card_to_pattern(card_str):
    """Convert 'G3' to 10-bit pattern: 1<<(color) | 1<<(5+value)"""
    color_char, value_char = card_str[0], card_str[1]
    color = COLOR_MAP[color_char]
    value = VALUE_MAP[value_char]
    return (1 << color) | (1 << (5 + value))

def compute_expected(card_strings):
    """Compute expected minimum hints using brute force"""
    if not card_strings:
        return 0
    distinct_patterns = set()
    for card in card_strings:
        distinct_patterns.add(card_to_pattern(card))
    
    if len(distinct_patterns) == 1:
        return 0
    
    min_hints = 10
    # Iterate over all 1024 mask combinations
    for mask in range(1024):
        signatures = set()
        valid = True
        for pattern in distinct_patterns:
            sig = pattern & mask
            if sig in signatures:
                valid = False
                break
            signatures.add(sig)
        if valid:
            popcount = bin(mask).count('1')
            if popcount < min_hints:
                min_hints = popcount
    return min_hints

async def reset_dut(dut, cycles=2):
    """Reset sequence"""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    dut.input_card.value = 0
    dut.n_in.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def feed_cards(dut, card_strings):
    """Feed cards to DUT serially"""
    dut.n_in.value = len(card_strings)
    await RisingEdge(dut.clk)
    
    for card in card_strings:
        pattern = card_to_pattern(card)
        dut.input_card.value = pattern
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.input_card.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hanabi_min_hints(dut):
    """Test Hanabi minimum hints module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases - scaled to n<=16
    test_cases = [
        ("G3 G3", 0),
        ("G4 R4 R3 B3", 2),
        ("B1 Y1 W1 G1 R1", 4),
        ("W3 Y5", 1),
        ("W5 Y5", 1),
        ("Y3 Y3 G3", 2),
        ("G3 G5", 1),
    ]
    
    for i, (cards_str, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {cards_str}")
        
        # Prepare cards
        card_strings = cards_str.split()
        
        # Feed cards
        await feed_cards(dut, card_strings)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read answer
        if not is_value_defined(dut.answer.value):
            raise TestFailure(f"Test {i+1}: Answer undefined")
        
        result = int(dut.answer.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
        
        # Wait before next test
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")