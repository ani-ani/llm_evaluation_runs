import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper Functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def char_to_ascii(c):
    return ord(c) if isinstance(c, str) and len(c) == 1 else 0

def pack_chars(s, length=16):
    """Pack string into 16x8 bits (Little Endian)"""
    val = 0
    for i, c in enumerate(s[:length]):
        val |= char_to_ascii(c) << (i * 8)
    return val

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_nvwls(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(3):
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    # Test Case 1
    dut._log.info("Running Test Case 1: Standard NVWLS")
    
    # Dictionary: 11 words
    words = [
        ("BETWEEN", 4), ("SUBTLE", 2), ("SHADING", 3), ("AND", 1),
        ("THE", 1), ("ABSENCE", 4), ("OF", 1), ("LIGHT", 2),
        ("LIES", 2), ("NUANCE", 4), ("IQLUSION", 5)
    ]
    
    # Expected Output Indices (0-based) based on input order
    # BETWEEN, SUBTLE, SHADING, AND, THE, ABSENCE, OF, LIGHT, LIES, THE, NUANCE, OF, IQLUSION
    exp_indices = [0, 1, 2, 3, 4, 5, 6, 7, 8, 4, 9, 6, 10]
    msg = "BTWNSBTLSHDNGNDTHBSNCFLGHTLSTHNNCFQLSN"
    
    if has_signal(dut, 'word_count'):
        dut.word_count.value = len(words)
    
    # Load Dictionary
    for i, (w, v) in enumerate(words):
        # Char array
        for c_idx, c in enumerate(w):
            if has_signal(dut, f'dict_word_{i}_char_{c_idx}'):
                getattr(dut, f'dict_word_{i}_char_{c_idx}').value = char_to_ascii(c)
        # Length
        if has_signal(dut, f'dict_word_{i}_len'):
            getattr(dut, f'dict_word_{i}_len').value = len(w)
        # Vowels
        if has_signal(dut, f'dict_word_{i}_vowels'):
            getattr(dut, f'dict_word_{i}_vowels').value = v

    # Load Message
    if has_signal(dut, 'msg_len'):
        dut.msg_len.value = len(msg)
    
    for i, c in enumerate(msg):
        if has_signal(dut, f'msg_char_{i}'):
            getattr(dut, f'msg_char_{i}').value = char_to_ascii(c)
        elif has_signal(dut, 'msg_char') and hasattr(dut.msg_char, '__getitem__'):
             dut.msg_char[i].value = char_to_ascii(c)

    # Start
    if has_signal(dut, 'start'):
        dut.start.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(10, units='ns')
        dut.start.value = 0
    
    # Wait for done
    timeout = 2048
    done = False
    for _ in range(timeout):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(10, units='ns')
        
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done = True
                break
    
    if not done:
        raise TestFailure("Timeout waiting for 'done' signal")

    # Check Results
    if has_signal(dut, 'valid'):
        if int(dut.valid.value) != 1:
            raise TestFailure("Valid signal is 0, expected 1")
            
    result_len = 0
    if has_signal(dut, 'result_len'):
        result_len = int(dut.result_len.value)
    
    if result_len != len(exp_indices):
        raise TestFailure(f"Result length mismatch: got {result_len}, expected {len(exp_indices)}")
    
    for i in range(result_len):
        # Try to read packed result or individual indices
        idx = -1
        if has_signal(dut, f'result_word_idx_{i}'):
            idx = int(getattr(dut, f'result_word_idx_{i}').value)
        elif has_signal(dut, 'result_word_idx') and hasattr(dut.result_word_idx, '__getitem__'):
            idx = int(dut.result_word_idx[i].value)
        
        if idx != exp_indices[i]:
             raise TestFailure(f"Index {i}: got {idx}, expected {exp_indices[i]}")
    
    dut._log.info("Test Case 1 Passed")
    
    # Test Case 2 (Simple repetition)
    dut._log.info("Running Test Case 2: Repetition")
    # Reset again for clean slate
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        for _ in range(2):
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

    words2 = [
        ("NA", 1), ("NNANNA", 2), ("NANNA", 2), ("BATMAN", 2)
    ]
    msg2 = "NNNNNNNNNNNNNBTMN"
    exp_indices2 = [0] * 13 + [3]
    
    if has_signal(dut, 'word_count'):
        dut.word_count.value = len(words2)

    for i, (w, v) in enumerate(words2):
        for c_idx, c in enumerate(w):
            if has_signal(dut, f'dict_word_{i}_char_{c_idx}'):
                getattr(dut, f'dict_word_{i}_char_{c_idx}').value = char_to_ascii(c)
        if has_signal(dut, f'dict_word_{i}_len'):
            getattr(dut, f'dict_word_{i}_len').value = len(w)
        if has_signal(dut, f'dict_word_{i}_vowels'):
            getattr(dut, f'dict_word_{i}_vowels').value = v

    if has_signal(dut, 'msg_len'):
        dut.msg_len.value = len(msg2)
    
    for i, c in enumerate(msg2):
        if has_signal(dut, f'msg_char_{i}'):
            getattr(dut, f'msg_char_{i}').value = char_to_ascii(c)
        elif has_signal(dut, 'msg_char') and hasattr(dut.msg_char, '__getitem__'):
             dut.msg_char[i].value = char_to_ascii(c)

    if has_signal(dut, 'start'):
        dut.start.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(10, units='ns')
        dut.start.value = 0

    done = False
    for _ in range(timeout):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(10, units='ns')
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done = True
                break
    
    if not done:
        raise TestFailure("Timeout waiting for 'done' signal (Case 2)")

    result_len2 = 0
    if has_signal(dut, 'result_len'):
        result_len2 = int(dut.result_len.value)
    
    if result_len2 != len(exp_indices2):
        raise TestFailure(f"Result length mismatch (Case 2): got {result_len2}, expected {len(exp_indices2)}")
    
    for i in range(result_len2):
        idx = -1
        if has_signal(dut, f'result_word_idx_{i}'):
            idx = int(getattr(dut, f'result_word_idx_{i}').value)
        elif has_signal(dut, 'result_word_idx') and hasattr(dut.result_word_idx, '__getitem__'):
            idx = int(dut.result_word_idx[i].value)
        
        if idx != exp_indices2[i]:
             raise TestFailure(f"Case 2 Index {i}: got {idx}, expected {exp_indices2[i]}")
             
    dut._log.info("Test Case 2 Passed")
