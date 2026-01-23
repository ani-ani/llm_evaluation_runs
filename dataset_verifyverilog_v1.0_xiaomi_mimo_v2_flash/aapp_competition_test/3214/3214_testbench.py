import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_WORDS = 8
MAX_LEN = 8
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS (from template)
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
# STRING PROCESSING FUNCTIONS
# ============================================================================

def extract_word_cores(text):
    """Extract word cores from text as per problem definition."""
    # Split by whitespace
    words = re.split(r'[\s]+', text)
    cores = []
    for word in words:
        if not word:
            continue
        # Check if contains at least one alphabetic character
        if not re.search(r'[a-zA-Z]', word):
            continue
        # Remove non-alphabetic and convert to lowercase
        core = ''.join(c for c in word if c.isalpha()).lower()
        if core:  # Should not be empty
            cores.append(core)
    return cores

def string_to_padded_bits(s, max_len=MAX_LEN):
    """Convert string to 64-bit value and length."""
    # Truncate if longer than max_len
    if len(s) > max_len:
        s = s[:max_len]
    length = len(s)
    # Pad with zeros (null bytes) to max_len
    s_padded = s.ljust(max_len, '\0')
    # Convert to 64-bit integer
    value = 0
    for i, char in enumerate(s_padded):
        value |= (ord(char) & 0xFF) << (8 * i)
    return value, length

def pack_words(word_list):
    """Pack list of word strings into words and word_lengths vectors."""
    words_vec = 0
    lengths_vec = 0
    for i, word in enumerate(word_list[:MAX_WORDS]):
        val, length = string_to_padded_bits(word, MAX_LEN)
        words_vec |= (val << (64 * i))
        lengths_vec |= (length << (4 * i))
    return words_vec, lengths_vec

def sort_words_alphabetically(words):
    """Sort words alphabetically, returning sorted list and original indices."""
    indexed_words = list(enumerate(words))
    indexed_words.sort(key=lambda x: x[1])
    sorted_indices = [idx for idx, _ in indexed_words]
    sorted_words = [word for _, word in indexed_words]
    return sorted_words, sorted_indices

def sort_strings_alphabetically(strings):
    """Sort strings alphabetically."""
    return sorted(strings)

# ============================================================================
# DUT RESET AND START HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_typo_checker(dut):
    """Main test function for typo checker."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    test_inputs = [
        "Lost is Close to Lose\n\n\"Better Documents Inc. wants to add Typo Checking in to the\nnext generation of word processors,\" he said.\n***\n",
        "The fox said, \"When?\"\n\"Not till 12 o'clock\", replied the hen.\n\"That clock is stopped, it will never strike.\", he said.\n***\n",
        "There are no similar words\nin this input set.\n***\n"
    ]
    
    expected_outputs = [
        "close: lose\nhe: the\nin: inc is\ninc: in\nis: in\nlose: close lost\nlost: lose\nthe: he\n",
        "clock: oclock\nhe: hen the\nhen: he when\nis: it\nit: is\noclock: clock\nthe: he\ntill: will\nwhen: hen\nwill: till\n",
        "***\n"
    ]
    
    for test_idx, (input_text, expected_output) in enumerate(zip(test_inputs, expected_outputs)):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test Case {test_idx + 1}")
        dut._log.info(f"{'='*60}")
        
        # Extract word cores
        word_cores = extract_word_cores(input_text)
        
        # Remove duplicates and sort
        unique_cores = sorted(set(word_cores))
        
        dut._log.info(f"Found {len(unique_cores)} unique word cores: {unique_cores}")
        
        # Pack into vectors
        words_vec, lengths_vec = pack_words(unique_cores)
        
        # Assign to DUT
        dut.word_count.value = len(unique_cores)
        
        # Assign words vector
        dut.words.value = words_vec
        
        # Assign lengths vector
        dut.word_lengths.value = lengths_vec
        
        # Start computation
        await start_computation(dut)
        
        # Collect pairs
        pairs = []  # List of (i, j)
        
        # Wait for pairs with timeout
        cycles = 0
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.pair_valid.value) and int(dut.pair_valid.value) == 1:
                i = int(dut.word1_idx.value)
                j = int(dut.word2_idx.value)
                pairs.append((i, j))
                dut._log.info(f"Pair found: {i} ({unique_cores[i]}) <-> {j} ({unique_cycles[j]})")
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            cycles += 1
        else:
            raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Wait one more cycle for done to clear
        await RisingEdge(dut.clk)
        
        # Build similarity mapping
        sim_map = {core: set() for core in unique_cores}
        for i, j in pairs:
            core_i = unique_cores[i]
            core_j = unique_cores[j]
            sim_map[core_i].add(core_j)
            sim_map[core_j].add(core_i)
        
        # Format output
        output_lines = []
        for core in sorted(sim_map.keys()):
            similar_cores = sorted(sim_map[core])
            if similar_cores:
                line = f"{core}: {' '.join(similar_cores)}"
                output_lines.append(line)
        
        if not output_lines:
            output_text = "***\n"
        else:
            output_text = "\n".join(output_lines) + "\n"
        
        dut._log.info(f"Generated output:\n{output_text}")
        dut._log.info(f"Expected output:\n{expected_output}")
        
        # Verify
        if output_text != expected_output:
            raise TestFailure(f"Test {test_idx + 1} failed: output mismatch")
        
        dut._log.info(f"Test {test_idx + 1} PASSED")
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info("\n" + "="*60)
    dut._log.info("ALL TESTS PASSED")
    dut._log.info("="*60)

# ============================================================================
# ADDITIONAL TEST: NO SIMILAR WORDS
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_no_similar_words(dut):
    """Test case with no similar words."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Input with no similar words
    input_text = "The quick brown fox jumps over the lazy dog.\n***\n"
    word_cores = extract_word_cores(input_text)
    unique_cores = sorted(set(word_cores))
    
    words_vec, lengths_vec = pack_words(unique_cores)
    
    dut.word_count.value = len(unique_cores)
    dut.words.value = words_vec
    dut.word_lengths.value = lengths_vec
    
    await start_computation(dut)
    
    # Wait for done
    cycles = 0
    found_pair = False
    while cycles < MAX_CYCLES:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.pair_valid.value) and int(dut.pair_valid.value) == 1:
            found_pair = True
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        cycles += 1
    else:
        raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
    
    if found_pair:
        raise TestFailure("Unexpected pair found for no-similar-words case")
    
    dut._log.info("No pairs found as expected")

# ============================================================================
# EDGE CASE: SINGLE WORD
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_single_word(dut):
    """Test case with single word."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    input_text = "Hello\n***\n"
    word_cores = extract_word_cores(input_text)
    unique_cores = sorted(set(word_cores))
    
    words_vec, lengths_vec = pack_words(unique_cores)
    
    dut.word_count.value = len(unique_cores)
    dut.words.value = words_vec
    dut.word_lengths.value = lengths_vec
    
    await start_computation(dut)
    
    # Wait for done
    cycles = 0
    found_pair = False
    while cycles < MAX_CYCLES:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.pair_valid.value) and int(dut.pair_valid.value) == 1:
            found_pair = True
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        cycles += 1
    else:
        raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
    
    if found_pair:
        raise TestFailure("Unexpected pair found for single-word case")
    
    dut._log.info("Single word handled correctly")

# ============================================================================
# TEST SIMILARITY LOGIC DIRECTLY
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_similarity_pairs(dut):
    """Verify similarity pairs are correct for known examples."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test known similar pairs
    test_cores = ["close", "lose", "lost", "he", "the", "in", "inc", "is"]
    
    words_vec, lengths_vec = pack_words(test_cores)
    
    dut.word_count.value = len(test_cores)
    dut.words.value = words_vec
    dut.word_lengths.value = lengths_vec
    
    await start_computation(dut)
    
    # Collect all pairs
    pairs = []
    cycles = 0
    while cycles < MAX_CYCLES:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.pair_valid.value) and int(dut.pair_valid.value) == 1:
            i = int(dut.word1_idx.value)
            j = int(dut.word2_idx.value)
            pairs.append((i, j))
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        cycles += 1
    else:
        raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
    
    # Expected pairs (indices in test_cores list)
    # close (0) <-> lose (1)  - replace 'c' with 'l'
    # lose (1) <-> lost (2)   - delete 't'
    # he (3) <-> the (4)      - insert 't' at beginning
    # in (5) <-> inc (6)      - insert 'c' at end
    # in (5) <-> is (7)       - replace 'n' with 's'
    # inc (6) <-> in (5)      - same as above (but we only output i<j)
    # is (7) <-> in (5)       - same as above (but we only output i<j)
    # Also: lose (1) <-> close (0) - but i<j so (0,1) already captured
    # lost (2) <-> lose (1) - but i<j so (1,2) captured
    
    expected_pairs = [(0,1), (1,2), (3,4), (5,6), (5,7)]
    
    # Sort pairs for comparison
    pairs_sorted = sorted(pairs)
    expected_sorted = sorted(expected_pairs)
    
    if pairs_sorted != expected_sorted:
        dut._log.error(f"Expected pairs: {expected_sorted}")
        dut._log.error(f"Got pairs: {pairs_sorted}")
        raise TestFailure("Pair mismatch for known similar words")
    
    dut._log.info("Similarity pairs verified correctly")

# ============================================================================
# TEST SIMILARITY MODULE IN ISOLATION (via internal signals)
# ============================================================================

# Note: This test assumes we can access internal signals of the similar module
# If not accessible, skip this test
@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_similarity_module(dut):
    """Direct test of similarity logic with known cases."""
    
    # Skip if internal signals not accessible
    if not hasattr(dut, 'sim_inst'):
        dut._log.info("Similarity module signals not accessible - skipping")
        return
    
    # Test cases: (word1, len1, word2, len2, expected_similar)
    test_cases = [
        # Delete: "abcd" -> "abd"
        (ord('a') | (ord('b')<<8) | (ord('c')<<16) | (ord('d')<<24), 4,
         ord('a') | (ord('b')<<8) | (ord('d')<<16), 3, True),
        # Insert: "abd" -> "abcd"
        (ord('a') | (ord('b')<<8) | (ord('d')<<16), 3,
         ord('a') | (ord('b')<<8) | (ord('c')<<16) | (ord('d')<<24), 4, True),
        # Replace: "abcd" -> "abxd"
        (ord('a') | (ord('b')<<8) | (ord('c')<<16) | (ord('d')<<24), 4,
         ord('a') | (ord('b')<<8) | (ord('x')<<16) | (ord('d')<<24), 4, True),
        # Transpose: "abcd" -> "abdc"
        (ord('a') | (ord('b')<<8) | (ord('c')<<16) | (ord('d')<<24), 4,
         ord('a') | (ord('b')<<8) | (ord('d')<<16) | (ord('c')<<24), 4, True),
        # Not similar: "abcd" -> "axyd" (2 replacements)
        (ord('a') | (ord('b')<<8) | (ord('c')<<16) | (ord('d')<<24), 4,
         ord('a') | (ord('x')<<8) | (ord('y')<<16) | (ord('d')<<24), 4, False),
    ]
    
    for idx, (w1, l1, w2, l2, expected) in enumerate(test_cases):
        # Assign to internal signals
        dut.sim_inst.word1.value = w1
        dut.sim_inst.len1.value = l1
        dut.sim_inst.word2.value = w2
        dut.sim_inst.len2.value = l2
        
        # Wait for propagation
        await Timer(10, units='ns')
        
        result = int(dut.sim_inst.is_similar.value)
        
        if result != (1 if expected else 0):
            raise TestFailure(f"Similarity test {idx} failed: expected {expected}, got {result}")
        
        dut._log.info(f"Similarity test {idx} passed")
