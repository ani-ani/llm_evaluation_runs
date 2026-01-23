import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
DATA_WIDTH = 8
STRING_LENGTH = 32
DICT_SIZE = 8
MAX_WORD_LENGTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS

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

def pack_string(s):
    """Pack a string into a 256-bit integer (32 chars)."""
    result = 0
    for i, c in enumerate(s):
        if i < 32:
            result |= (ord(c) & 0xFF) << (i * 8)
    return result

def unpack_string(val, length=32):
    """Unpack a 256-bit integer into a string."""
    s = ""
    for i in range(length):
        char = (val >> (i * 8)) & 0xFF
        if char == 0:
            break
        s += chr(char)
    return s

def pack_dict_words(words):
    """Pack 8 words into 512-bit integer."""
    result = 0
    for i, word in enumerate(words):
        if i < 8:
            word_val = 0
            for j, c in enumerate(word):
                if j < 8:
                    word_val |= (ord(c) & 0xFF) << (j * 8)
            result |= word_val << (i * 64)
    return result

def pack_dict_lengths(lengths):
    """Pack 8 lengths into 32-bit integer."""
    result = 0
    for i, length in enumerate(lengths):
        if i < 8:
            result |= (length & 0xF) << (i * 4)
    return result

# ============================================================================
# ARRAY ACCESS HELPERS

def write_string(dut, s):
    """Write string to DUT input."""
    packed = pack_string(s)
    dut.string_in.value = packed

def write_dictionary(dut, words):
    """Write dictionary to DUT."""
    lengths = [len(w) for w in words]
    packed_words = pack_dict_words(words)
    packed_lengths = pack_dict_lengths(lengths)
    dut.dict_words.value = packed_words
    dut.dict_lengths.value = packed_lengths

# ============================================================================
# SEQUENTIAL MODULE HELPERS

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
# TEST CASES

test_cases = [
    {
        "input": "tihssnetnceemkaesprfecetsesne",
        "dictionary": ["makes", "perfect", "sense", "sentence", "this"],
        "expected_status": 0,  # valid
        "description": "Sample 1: valid segmentation"
    },
    {
        "input": "hitehre",
        "dictionary": ["there", "hello"],
        "expected_status": 1,  # impossible
        "description": "Sample 2: impossible"
    },
    {
        "input": "hitehre",
        "dictionary": ["hi", "there", "three"],
        "expected_status": 2,  # ambiguous
        "description": "Sample 3: ambiguous"
    },
    {
        "input": "a",
        "dictionary": ["a"],
        "expected_status": 0,
        "description": "Single character match"
    },
    {
        "input": "ab",
        "dictionary": ["ab", "ba"],
        "expected_status": 1,  # impossible (no match for "ab" with scrambling)
        "description": "Two character mismatch"
    },
    {
        "input": "abc",
        "dictionary": ["abc", "acb"],
        "expected_status": 2,  # ambiguous
        "description": "Three character ambiguous"
    },
]

# ============================================================================
# MAIN TEST

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_decipher(dut):
    """Main test function."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {test['description']}")
        cocotb.log.info(f"Input: {test['input']}")
        cocotb.log.info(f"Dictionary: {test['dictionary']}")
        cocotb.log.info(f"Expected status: {test['expected_status']} (0=valid, 1=impossible, 2=ambiguous)")
        
        try:
            # Write inputs
            write_string(dut, test['input'])
            write_dictionary(dut, test['dictionary'])
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            if not is_value_defined(dut.result_status.value):
                raise TestFailure("Result status is undefined (X/Z)")
            
            status = int(dut.result_status.value)
            
            # Read result sentence
            sentence_val = safe_int(dut.result_sentence.value, 0)
            sentence = unpack_string(sentence_val, 32)
            
            cocotb.log.info(f"Actual status: {status}")
            cocotb.log.info(f"Result sentence: {sentence!r}")
            
            # Verify status
            if status != test['expected_status']:
                raise TestFailure(f"Status mismatch: expected {test['expected_status']}, got {status}")
            
            # Additional checks based on expected status
            if status == 0:  # valid
                # For valid, we expect some sentence output
                if len(sentence) == 0:
                    raise TestFailure("Valid status but empty sentence")
            elif status == 1:  # impossible
                if "impossible" not in sentence.lower():
                    raise TestFailure(f"Expected 'impossible' in sentence, got: {sentence}")
            elif status == 2:  # ambiguous
                if "ambiguous" not in sentence.lower():
                    raise TestFailure(f"Expected 'ambiguous' in sentence, got: {sentence}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")