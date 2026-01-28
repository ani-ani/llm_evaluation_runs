import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_WORDS = 16
WORD_LEN = 8
PACKED_WIDTH = 64
CLK_NS = 10
MAX_CYCLES = 2048

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_word(s):
    """Pack string to 64-bit integer (8 bytes, LSB first). Pad with 0x20."""
    s = s.ljust(WORD_LEN)
    val = 0
    for i in range(WORD_LEN):
        # ASCII to integer
        val |= (ord(s[i]) & 0xFF) << (i * 8)
    return val

def unpack_word(val):
    """Unpack 64-bit integer to string."""
    s = ""
    for i in range(WORD_LEN):
        char_code = (val >> (i * 8)) & 0xFF
        s += chr(char_code)
    return s

def unique_count_str(s):
    """Compute unique chars in string (case-insensitive a-z)."""
    seen = set()
    for c in s:
        lc = c.lower()
        if 'a' <= lc <= 'z':
            seen.add(lc)
    return len(seen)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_find_max_word(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases
    test_cases = [
        ("name", "of", "string"),
        ("name", "enam", "game"),
        ("aaaaaaa", "bb", "cc"),
        ("abc", "cba"),
        ("play", "this", "game", "of", "footbott"),
        ("we", "are", "gonna", "rock"),
        ("we", "are", "a", "mad", "nation"),
        ("this", "is", "a", "prrk"),
        ("b",),
        ("play", "play", "play")
    ]

    for words in test_cases:
        num_words = len(words)
        
        # Calculate Expected Result
        best_word = ""
        best_uniques = -1
        
        for w in words:
            u = unique_count_str(w)
            if u > best_uniques:
                best_uniques = u
                best_word = w
            elif u == best_uniques:
                if best_word == "" or w < best_word:
                    best_word = w
        
        expected_packed = pack_word(best_word)
        
        cocotb.log.info(f"Testing input: {words}, Expected: '{best_word}' (uniques: {best_uniques})")

        # Load Inputs
        dut.num_words.value = num_words
        for i in range(MAX_WORDS):
            packed = 0
            if i < num_words:
                packed = pack_word(words[i])
            dut.words_data[i].value = packed

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait
        await wait_for_done(dut)

        # Check Output
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
        
        result = int(dut.result.value)
        result_str = unpack_word(result)
        
        # Trim padding for comparison if needed, but strictly checking packed values is safer for HDL
        # The spec says return the word. Usually implies the string content.
        # Let's compare the unpacked strings (trimming trailing spaces)
        result_str_trimmed = result_str.rstrip()
        expected_str_trimmed = best_word.rstrip() if best_word else ""

        if result_str_trimmed != expected_str_trimmed:
             raise TestFailure(f"Mismatch: Input {words}, Got '{result_str_trimmed}' (pack {result}), Exp '{expected_str_trimmed}' (pack {expected_packed})")

        # Small delay between tests
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)
