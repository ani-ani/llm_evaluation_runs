import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
STRING_LEN = 32  # 4 lines of 8 chars
WORD_LEN = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def pack_string(s, max_len=STRING_LEN):
    """Pack string into array of ASCII values."""
    result = [ord(c) for c in s[:max_len]]
    # Pad with zeros
    while len(result) < max_len:
        result.append(0)
    return result

def pack_test_input(strings):
    """Pack list of strings into 32-char array (4 lines of 8 chars)."""
    combined = "".join(s.ljust(8)[:8] for s in strings[:4])
    return pack_string(combined)

def extract_word(word_array):
    """Extract word from array of 8 chars."""
    chars = []
    for i in range(WORD_LEN):
        if is_value_defined(word_array[i]):
            val = int(word_array[i])
            if val != 0:
                chars.append(chr(val))
    return "".join(chars)

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_char_array(dut, values):
    """Write 32 chars to char_in array."""
    for i in range(STRING_LEN):
        dut.char_in[i].value = clamp_to_width(values[i], DATA_WIDTH)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_word_finder(dut):
    """Test word finder with P-prefixed words."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_strings, expected_word1, expected_word2)
    test_cases = [
        ("Python PHP", "Java JavaScript", "c c++"),
        ("Python Programming", "Java Programming"),
        ("Pqrst Pqr", "qrstuv"),
    ]
    
    expected_results = [
        ("Python", "PHP"),
        ("Python", "Programming"),
        ("Pqrst", "Pqr"),
    ]
    
    for i, (strings, (exp_w1, exp_w2)) in enumerate(zip(test_cases, expected_results)):
        cocotb.log.info(f"\nTest {i+1}: Input strings: {strings}")
        
        # Pack input
        input_data = pack_test_input(strings)
        cocotb.log.info(f"Input packed: {input_data}")
        
        # Write to DUT
        await write_char_array(dut, input_data)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check found flag
        if not is_value_defined(dut.found.value):
            raise TestFailure(f"Test {i+1}: found signal is undefined")
        
        found = int(dut.found.value)
        if found != 1:
            raise TestFailure(f"Test {i+1}: found should be 1, got {found}")
        
        # Read word1
        word1_chars = []
        for j in range(WORD_LEN):
            if is_value_defined(dut.word1[j].value):
                val = int(dut.word1[j].value)
                if val != 0:
                    word1_chars.append(chr(val))
        word1_result = "".join(word1_chars)
        
        # Read word2
        word2_chars = []
        for j in range(WORD_LEN):
            if is_value_defined(dut.word2[j].value):
                val = int(dut.word2[j].value)
                if val != 0:
                    word2_chars.append(chr(val))
        word2_result = "".join(word2_chars)
        
        cocotb.log.info(f"  Word1: '{word1_result}' (expected '{exp_w1}')")
        cocotb.log.info(f"  Word2: '{word2_result}' (expected '{exp_w2}')")
        
        if word1_result != exp_w1:
            raise TestFailure(f"Test {i+1}: Word1 mismatch: expected '{exp_w1}', got '{word1_result}'")
        if word2_result != exp_w2:
            raise TestFailure(f"Test {i+1}: Word2 mismatch: expected '{exp_w2}', got '{word2_result}'")
        
        cocotb.log.info(f"  PASS")
        
        # Wait for done to go low
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"All {len(test_cases)} tests passed!")
