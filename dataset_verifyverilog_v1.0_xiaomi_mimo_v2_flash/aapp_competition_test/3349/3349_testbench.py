import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
# TEST FUNCTION
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_no_vowels_reconstructor(dut):
    """Test the no_vowels_reconstructor module."""
    
    # Configuration
    MAX_WORDS = 4
    MAX_WORD_LEN = 8
    MAX_MSG_LEN = 16
    DATA_WIDTH = 8
    
    # Helper functions for packing
    def pack_skeleton_chars(words):
        packed = 0
        for i, word in enumerate(words):
            if i >= MAX_WORDS:
                break
            slice_val = 0
            for j, ch in enumerate(word[:MAX_WORD_LEN]):
                slice_val |= (ord(ch) & 0xFF) << (8 * (7 - j))
            packed |= slice_val << (64 * i)
        return packed
    
    def pack_skeleton_len(lengths):
        packed = 0
        for i, l in enumerate(lengths[:MAX_WORDS]):
            packed |= (l & 0xF) << (4 * i)
        return packed
    
    def pack_vowel_count(counts):
        packed = 0
        for i, c in enumerate(counts[:MAX_WORDS]):
            packed |= (c & 0xF) << (4 * i)
        return packed
    
    def pack_message(msg_str):
        packed = 0
        for i, ch in enumerate(msg_str[:MAX_MSG_LEN]):
            packed |= (ord(ch) & 0xFF) << (8 * (MAX_MSG_LEN - 1 - i))
        return packed
    
    # Detect required signals
    if not has_signal(dut, 'clk') or not has_signal(dut, 'rst_n') or not has_signal(dut, 'start'):
        raise TestFailure("DUT missing required control signals")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case data
    original_words = ["NA", "NNANNA", "NANNA", "BATMAN"]
    skeletons = []
    vowel_counts = []
    for word in original_words:
        skeleton = ''.join([c for c in word if c not in 'AEIOU'])
        vowels = len([c for c in word if c in 'AEIOU'])
        skeletons.append(skeleton)
        vowel_counts.append(vowels)
    
    # Expected output indices: 12 times index 0, then index 3
    expected_indices = [0] * 12 + [3]
    
    # Message (12 N's + BTMN = 16 characters)
    message = "N" * 12 + "BTMN"
    msg_len = len(message)
    
    # Pack data
    packed_skeleton_chars = pack_skeleton_chars(skeletons)
    packed_skeleton_len = pack_skeleton_len([len(s) for s in skeletons])
    packed_vowel_count = pack_vowel_count(vowel_counts)
    packed_message = pack_message(message)
    num_words = len(original_words)
    
    # Assign to DUT
    dut.skeleton_chars.value = packed_skeleton_chars
    dut.skeleton_len.value = packed_skeleton_len
    dut.vowel_count.value = packed_vowel_count
    dut.num_words.value = num_words
    dut.message.value = packed_message
    dut.msg_len.value = msg_len
    
    # Pulse start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Capture output
    captured_indices = []
    timeout_cycles = 5000
    cycles = 0
    
    while cycles < timeout_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if has_signal(dut, 'word_valid') and has_signal(dut, 'word_index'):
            if is_value_defined(dut.word_valid.value) and int(dut.word_valid.value) == 1:
                if is_value_defined(dut.word_index.value):
                    idx = int(dut.word_index.value)
                    captured_indices.append(idx)
        
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    if cycles >= timeout_cycles:
        raise TestFailure(f"Timeout after {timeout_cycles} cycles")
    
    # Verify
    if len(captured_indices) != len(expected_indices):
        raise TestFailure(f"Expected {len(expected_indices)} words, got {len(captured_indices)}")
    
    for i, (exp, cap) in enumerate(zip(expected_indices, captured_indices)):
        if exp != cap:
            raise TestFailure(f"Word {i}: expected index {exp}, got {cap}")
    
    # Reconstruct sentence for log
    sentence = ' '.join([original_words[i] for i in captured_indices])
    dut._log.info(f"Reconstructed sentence: {sentence}")
    dut._log.info("Test PASSED")
