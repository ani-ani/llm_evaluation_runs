import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 4
MAX_LEN = 4
CHAR_WIDTH = 8
DATA_WIDTH = N * MAX_LEN * CHAR_WIDTH
LEN_WIDTH = N * 4

# ============================================================================
# HELPER FUNCTIONS
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
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY PACKING HELPERS
# ============================================================================

def pack_word_data(words, max_len, char_width):
    packed = 0
    for i, word in enumerate(words):
        for j in range(max_len):
            if j < len(word):
                char = ord(word[j])
            else:
                char = 0
            offset = (i * max_len + j) * char_width
            packed |= char << offset
    return packed

def pack_word_len(words):
    packed = 0
    for i, word in enumerate(words):
        length = len(word)
        packed |= length << (i * 4)
    return packed

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_typo_detector(dut):
    """Test typo detector module."""
    
    # Define test cases: (words_list, expected_typo_mask)
    test_cases = [
        # Case 1: hoos (typo) and hose -> mask 0b01
        ("hoos", "hose"),  # 0b01
        # Case 2: hose, hoos -> mask 0b10
        ("hose", "hoos"),  # 0b10
        # Case 3: No typos
        ("abc", "def"),    # 0b00
        # Case 4: Multiple typos
        ("ab", "a", "cd", "c"),  # 0b0101 (bits 0 and 2 set)
    ]
    
    # Convert test cases to the expected mask and words list
    test_data = []
    for case in test_cases:
        words = list(case[:-1]) if isinstance(case[-1], int) else list(case)
        expected_mask = case[-1] if isinstance(case[-1], int) else 0
        test_data.append((words, expected_mask))
    
    for idx, (words, expected_mask) in enumerate(test_data):
        dut._log.info(f"Test case {idx+1}: words={words}, expected_mask={bin(expected_mask)}")
        
        # Pack the inputs
        packed_data = pack_word_data(words, MAX_LEN, CHAR_WIDTH)
        packed_len = pack_word_len(words)
        
        # Assign to DUT
        if has_signal(dut, 'word_data'):
            dut.word_data.value = clamp_to_width(packed_data, DATA_WIDTH)
        else:
            raise TestFailure("Signal 'word_data' not found")
        
        if has_signal(dut, 'word_len'):
            dut.word_len.value = clamp_to_width(packed_len, LEN_WIDTH)
        else:
            raise TestFailure("Signal 'word_len' not found")
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Read output
        if not is_value_defined(dut.typo_mask.value):
            raise TestFailure(f"Test {idx+1}: typo_mask is undefined (X/Z)")
        
        actual_mask = int(dut.typo_mask.value)
        
        # Mask out unused bits
        num_words = len(words)
        mask_mask = (1 << num_words) - 1
        actual_mask &= mask_mask
        
        if actual_mask != expected_mask:
            raise TestFailure(f"Test {idx+1}: expected {bin(expected_mask)}, got {bin(actual_mask)}")
        
        dut._log.info(f"  PASS: typo_mask = {bin(actual_mask)}")
    
    dut._log.info("All tests passed!")