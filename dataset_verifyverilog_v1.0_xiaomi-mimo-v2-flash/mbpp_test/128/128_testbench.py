import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

def encode_string(s):
    """Pack 8-character string into 64-bit value"""
    if len(s) > 8:
        s = s[:8]
    elif len(s) < 8:
        s = s.ljust(8, ' ')  # Pad with spaces
    result = 0
    for i, ch in enumerate(s):
        result |= (ord(ch) & 0xFF) << ((7 - i) * 8)  # MSB first
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_result_words(vals, bits=8):
    """Pack 8 words of 8 chars each into 64-bit result_words"""
    result = 0
    for i, word_val in enumerate(vals):
        if i >= 8:
            break
        result |= ((word_val & ((1 << (8 * bits)) - 1)) << (i * 8 * bits))
    return result

def decode_result_words(packed_val, count):
    """Extract words from packed result"""
    words = []
    for i in range(count):
        word_val = (packed_val >> (i * 64)) & ((1 << 64) - 1)
        chars = []
        for j in range(8):
            ch = (word_val >> ((7 - j) * 8)) & 0xFF
            if ch != 0 and ch != 32:  # Not null or space
                chars.append(chr(ch))
        if chars:
            words.append(''.join(chars))
    return words

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_long_words(dut):
    # Setup
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # (input_str, threshold, expected_count, expected_words_list, description)
        ("python is", 3, 2, ['python', 'is'], "Test 1: threshold=3"),
        ("writing a", 2, 2, ['writing', 'a'], "Test 2: threshold=2"),
        ("sorting l", 5, 1, ['sorting'], "Test 3: threshold=5"),
        ("test     ", 2, 1, ['test'], "Single word with spaces"),
        ("a b c d ", 0, 4, ['a', 'b', 'c', 'd'], "All words longer than 0"),
        ("12345678", 8, 0, [], "No words longer than 8"),
    ]
    
    passed = failed = 0
    
    for i, (inp_str, threshold, exp_count, exp_words, desc) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"Input: '{inp_str}' (len={len(inp_str)}), Threshold={threshold}")
        
        try:
            # Encode input string
            encoded = encode_string(inp_str)
            cocotb.log.info(f"Encoded string: 0x{encoded:016X}")
            
            # Set inputs
            dut.input_str.value = encoded
            dut.threshold.value = threshold
            dut.start.value = 1
            
            # Wait for start pulse
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.result_count.value):
                raise TestFailure("Result count undefined")
            
            result_count = int(dut.result_count.value)
            result_words_packed = int(dut.result_words.value)
            
            cocotb.log.info(f"Result count: {result_count}")
            cocotb.log.info(f"Result words packed: 0x{result_words_packed:032X}")
            
            # Decode and compare
            decoded_words = decode_result_words(result_words_packed, result_count)
            cocotb.log.info(f"Decoded words: {decoded_words}")
            
            # Validate count
            if result_count != exp_count:
                raise TestFailure(f"Count mismatch: expected {exp_count}, got {result_count}")
            
            # Validate words (order may vary, but counts and contents must match)
            if len(decoded_words) != len(exp_words):
                raise TestFailure(f"Word count mismatch: expected {len(exp_words)} words, got {len(decoded_words)}")
            
            # Check each expected word is present
            for word in exp_words:
                if word not in decoded_words:
                    raise TestFailure(f"Expected word '{word}' not found in result: {decoded_words}")
            
            cocotb.log.info(f"✓ Test passed: {desc}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"✗ FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Summary: {passed} passed, {failed} failed")
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")