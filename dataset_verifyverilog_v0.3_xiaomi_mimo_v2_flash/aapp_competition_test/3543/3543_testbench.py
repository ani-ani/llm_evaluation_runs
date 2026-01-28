import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
NUM_DICT_WORDS = 8
MAX_WORD_LEN = 16
DATA_WIDTH = 8
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

def pack_string(s, max_len=MAX_WORD_LEN):
    """Pack a string into a 128-bit integer (16 chars * 8 bits)."""
    packed = 0
    s = s[:max_len]  # Truncate if needed
    for i, c in enumerate(s):
        packed |= (ord(c) & 0xFF) << (i * 8)
    return packed

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

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
# LOAD DICTIONARY
# ============================================================================

async def load_dictionary(dut, dictionary):
    """Load dictionary words and lengths into the DUT."""
    # Dictionary should be a list of (word, frequency) tuples
    # We take the first NUM_DICT_WORDS words
    words = [w for w, _ in dictionary[:NUM_DICT_WORDS]]
    
    # Pack each word and assign
    for i, word in enumerate(words):
        packed = pack_string(word, MAX_WORD_LEN)
        
        # Assign packed word
        dut.dict_words_packed[i].value = packed
        
        # Assign length
        length = len(word) if len(word) <= MAX_WORD_LEN else MAX_WORD_LEN
        dut.dict_lens[i].value = length
        
        dut._log.info(f"Dictionary word {i}: '{word}' (len={length}) packed=0x{packed:032X}")
    
    # Fill remaining dictionary slots with zeros
    for i in range(len(words), NUM_DICT_WORDS):
        dut.dict_words_packed[i].value = 0
        dut.dict_lens[i].value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_autocorrect_min_keystrokes(dut):
    """Test the autocorrect minimum keystrokes module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Dictionary: (word, frequency) - will be sorted by frequency for real problem
    # We use a small set for testing
    dictionary = [
        ("austria", 1),
        ("autocorrect", 2),
        ("program", 3),
        ("programming", 4),
        ("computer", 5),
    ]
    
    # Load dictionary into DUT
    await load_dictionary(dut, dictionary)
    
    # Test cases: (input_word, expected_keystrokes)
    test_cases = [
        ("autocorrelation", 12),
        ("programming", 4),
        ("competition", 11),
        ("zyx", 3),
        ("austria", 2),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_word, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: Typing '{input_word}'")
        
        try:
            # Pack input word
            packed_input = pack_string(input_word, MAX_WORD_LEN)
            input_len = len(input_word) if len(input_word) <= MAX_WORD_LEN else MAX_WORD_LEN
            
            # Set inputs
            dut.input_word_packed.value = packed_input
            dut.input_len.value = input_len
            
            # Wait one cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: {input_word} => {result} keystrokes")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")