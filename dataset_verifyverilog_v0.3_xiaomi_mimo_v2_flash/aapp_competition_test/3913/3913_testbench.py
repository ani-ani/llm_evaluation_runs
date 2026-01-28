import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY/PATTERN PACKING HELPERS
# ============================================================================

def pack_string(s, max_len=8):
    """Pack string into 64-bit integer (8 characters, LSB first)."""
    if len(s) > max_len:
        s = s[:max_len]
    res = 0
    for i, char in enumerate(s):
        res |= (ord(char) & 0xFF) << (8 * i)
    return res

def pack_words(words, max_words=8, max_len=8):
    """Pack list of words into 8 separate 64-bit integers."""
    packed = [0] * max_words
    for i, word in enumerate(words[:max_words]):
        if len(word) > max_len:
            word = word[:max_len]
        for j, char in enumerate(word):
            packed[i] |= (ord(char) & 0xFF) << (8 * j)
    return packed

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=100):
    """Wait for done signal with timeout."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_field_of_wonders(dut):
    """Test the field_of_wonders module."""
    
    # Configuration based on module parameters
    MAX_N = 8
    MAX_M = 8
    CLK_PERIOD = 10  # ns
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, pattern, m, words, expected_output, description)
    test_cases = [
        # Original examples scaled to max 8 chars/words
        (4, "a**d", 2, ["abcd", "acbd"], 2, "Example 1: two valid letters b,c"),
        (5, "lo*er", 2, ["lover", "loser"], 0, "Example 2: ambiguous third letter"),
        (3, "a*a", 2, ["aaa", "aba"], 1, "Example 3: only 'b' works"),
        
        # Additional scaled test cases
        (1, "*", 1, ["a"], 1, "Single hidden, one word"),
        (1, "*", 1, ["z"], 1, "Single hidden, one word - z"),
        (1, "*", 2, ["a", "z"], 0, "Single hidden, two words - no common"),
        (2, "**", 1, ["aa"], 1, "Two hidden, one word - both 'a'"),
        (2, "**", 1, ["fx"], 2, "Two hidden, one word - two letters"),
        (2, "**", 2, ["fx", "ab"], 0, "Two hidden, two words - no common"),
        (2, "a*", 2, ["aa", "ab"], 1, "Partial hidden - 'b' only"),
        (4, "a*b*", 2, ["abbc", "adbd"], 1, "Two hidden positions - 'c' only"),
        (4, "a*b*", 3, ["abbc", "adbd", "acbe"], 0, "Three words - ambiguous"),
        (3, "***", 2, ["aaa", "bbb"], 0, "All hidden, two words - no common"),
        (3, "***", 2, ["aab", "abb"], 2, "All hidden, two words - two letters"),
        (3, "*a*", 4, ["aaa", "cac", "aab", "baa"], 1, "Middle revealed - 'b' only"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, pattern_str, m, words, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Pack pattern and words
            pattern_packed = pack_string(pattern_str, MAX_N)
            words_packed = pack_words(words, MAX_M, MAX_N)
            
            # Assign inputs
            dut.n.value = n
            dut.pattern.value = pattern_packed
            dut.m.value = m
            
            # Assign each word individually
            for j in range(MAX_M):
                if j < len(words_packed):
                    setattr(dut, f'word{j}', words_packed[j])
                else:
                    setattr(dut, f'word{j}', 0)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut, 100)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
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
