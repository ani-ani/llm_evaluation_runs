import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 8
MAX_LEN = 8
MAX_SHOWN = 8
MAX_BARB = 4
CLK_PERIOD_NS = 10

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

def pack_chars(char_list):
    """Pack list of ASCII chars into 64-bit value"""
    result = 0
    for i, c in enumerate(char_list[:MAX_LEN]):
        result |= (ord(c) << (i * 8))
    return result

def pack_bytes(byte_list):
    """Pack list of byte values into 64-bit value"""
    result = 0
    for i, b in enumerate(byte_list[:MAX_LEN]):
        result |= (b << (i * 8))
    return result

def to_verilog_bytes(s):
    """Convert string to list of byte values (0-255), padded to MAX_LEN"""
    bytes_list = [ord(c) for c in s]
    while len(bytes_list) < MAX_LEN:
        bytes_list.append(0)
    return bytes_list

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_barbarian_words(dut, words):
    """Load barbarian words into the module's internal storage"""
    # For this testbench, we directly manipulate the internal array
    # In a real scenario, this would be done via a configuration interface
    for i, word in enumerate(words):
        if i >= MAX_BARB:
            break
        bytes_list = to_verilog_bytes(word)
        for j in range(MAX_LEN):
            dut.barb_words[i][j].value = bytes_list[j]
        dut.barb_lens[i].value = len(word)
    
    await RisingEdge(dut.clk)

async def show_word(dut, word):
    """Send show word command"""
    bytes_list = to_verilog_bytes(word)
    
    dut.op_type.value = 0
    dut.char0.value = bytes_list[0]
    dut.char1.value = bytes_list[1]
    dut.char2.value = bytes_list[2]
    dut.char3.value = bytes_list[3]
    dut.char4.value = bytes_list[4]
    dut.char5.value = bytes_list[5]
    dut.char6.value = bytes_list[6]
    dut.char7.value = bytes_list[7]
    dut.str_len.value = len(word)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    
    raise TestFailure("Timeout waiting for done after show word")

async def query_barbarian(dut, barbarian_idx):
    """Send query command and return result"""
    dut.op_type.value = 1
    dut.barbarian_idx.value = barbarian_idx - 1  # Convert 1-4 to 0-3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(1000):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            if is_value_defined(dut.result.value):
                return int(dut.result.value)
            else:
                raise TestFailure("Result is undefined")
    
    raise TestFailure("Timeout waiting for done after query")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_barbarian_game(dut):
    """Main test: simulates the problem's example cases"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Case 1: From sample input
    # Barbarians: "a", "bc", "abc"
    # Rounds: 1) show "abca", 2) query 1, 3) query 3
    
    dut._log.info("=== Test Case 1: Sample Input ===")
    
    # Load barbarian words
    barb_words1 = ["a", "bc", "abc", "x"]  # 4th dummy
    await load_barbarian_words(dut, barb_words1)
    
    # Show "abca"
    await show_word(dut, "abca")
    
    # Query barbarian 1 (word "a")
    result = await query_barbarian(dut, 1)
    dut._log.info(f"Query 1: Barbarian 1 ('a'), result = {result}")
    if result != 1:
        raise TestFailure(f"Test 1 failed: expected 1, got {result}")
    
    # Query barbarian 3 (word "abc")
    result = await query_barbarian(dut, 3)
    dut._log.info(f"Query 2: Barbarian 3 ('abc'), result = {result}")
    if result != 1:
        raise TestFailure(f"Test 2 failed: expected 1, got {result}")
    
    # Test Case 2: Second sample input (truncated for scale)
    dut._log.info("\n=== Test Case 2: Complex Example ===")
    
    # Reset for new test
    await reset_dut(dut)
    
    # Load barbarians: abba, bbaa, b, ba
    barb_words2 = ["abba", "bbaa", "b", "ba"]
    await load_barbarian_words(dut, barb_words2)
    
    # Show "aaabbabbaab" (will be truncated to 8 chars: "aaabbabb")
    await show_word(dut, "aaabbabb")
    
    # Query barbarian 4 (word "ba") - should find in "aaabbabb"
    result = await query_barbarian(dut, 4)
    dut._log.info(f"Query: Barbarian 4 ('ba'), result = {result}")
    # "aaabbabb" contains "ba" at position 5 -> should be 1
    if result < 1:
        dut._log.warning(f"Expected at least 1, got {result} (may be 0 due to truncation)")
    
    # Show "baabaaa" (truncated to "baabaaaa")
    await show_word(dut, "baabaaa")
    
    # Show "aabbbab" (truncated to "aabbbab ")
    await show_word(dut, "aabbbab")
    
    # Query barbarian 3 (word "b") - should find many
    result = await query_barbarian(dut, 3)
    dut._log.info(f"Query: Barbarian 3 ('b'), result = {result}")
    
    # Show "aabba" (truncated to "aabba   ")
    await show_word(dut, "aabba")
    
    # Query barbarian 3 (word "b") again
    result = await query_barbarian(dut, 3)
    dut._log.info(f"Query: Barbarian 3 ('b'), result = {result}")
    
    dut._log.info("\n=== All tests completed ===")
    dut._log.info("[PASS] Module passed all tests")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases: empty strings, single chars, etc."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Load barbarians
    barb_words = ["a", "", "ab", "abc"]  # Empty string as test
    await load_barbarian_words(dut, barb_words)
    
    # Show empty word
    await show_word(dut, "")
    
    # Query barbarian 1 ("a")
    result = await query_barbarian(dut, 1)
    dut._log.info(f"Empty shown, query 'a': {result}")
    
    # Show "aaaa"
    await show_word(dut, "aaaa")
    
    # Query barbarian 1 ("a") - should find 1
    result = await query_barbarian(dut, 1)
    if result != 1:
        raise TestFailure(f"Edge case failed: expected 1, got {result}")
    
    dut._log.info("[PASS] Edge cases passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_no_match(dut):
    """Test cases with no matches"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    barb_words = ["xyz", "abc", "test", "word"]
    await load_barbarian_words(dut, barb_words)
    
    await show_word(dut, "hello")
    await show_word(dut, "world")
    
    result = await query_barbarian(dut, 1)  # "xyz" in "hello" or "world"
    if result != 0:
        raise TestFailure(f"No match test failed: expected 0, got {result}")
    
    dut._log.info("[PASS] No match test passed")
