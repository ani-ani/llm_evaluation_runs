import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, MAX_LEN, CLK_NS, MAX_CYCLES = 8, 16, 10, 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string(dut, s):
    # Clear string input
    for i in range(MAX_LEN):
        dut.str_in[i].value = 0
    # Write characters
    for i, c in enumerate(s[:MAX_LEN]):
        dut.str_in[i].value = ord(c)
    dut.len.value = clamp_to_width(len(s), 4)

async def pack_words(words):
    result = 0
    for i, word in enumerate(words[:8]):
        word_packed = 0
        for j, c in enumerate(word[:8]):
            word_packed |= (ord(c) << (j * 8))
        result |= word_packed << (i * 64)
    return result

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_words_string(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("Hi, my name is John", ["Hi", "my", "name", "is", "John"], 5),
        ("One, two, three, four, five, six", ["One", "two", "three", "four", "five", "six"], 6),
        ("Hi, my name", ["Hi", "my", "name"], 3),
        ("One,, two, three, four, five, six,", ["One", "two", "three", "four", "five", "six"], 6),
        ("", [], 0),
        ("ahmed     , gamal", ["ahmed", "gamal"], 2),
        ("Hello", ["Hello"], 1),
        (", , ,", [], 0),
    ]
    
    passed = failed = 0
    
    for i, (inp_str, expected_words, expected_count) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{inp_str}'")
        try:
            await write_string(dut, inp_str)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.word_count.value):
                raise TestFailure("word_count undefined")
            
            word_count = int(dut.word_count.value)
            if word_count != expected_count:
                raise TestFailure(f"Expected word_count={expected_count}, got {word_count}")
            
            if word_count > 0:
                if not is_value_defined(dut.words_out.value):
                    raise TestFailure("words_out undefined")
                
                words_out_val = int(dut.words_out.value)
                # Extract each word and verify
                for idx, exp_word in enumerate(expected_words):
                    word_bits = (words_out_val >> (idx * 64)) & 0xFFFFFFFFFFFFFFFF
                    # Compare characters
                    for char_idx, exp_char in enumerate(exp_word[:8]):
                        extracted = (word_bits >> (char_idx * 8)) & 0xFF
                        if extracted != ord(exp_char):
                            raise TestFailure(
                                f"Word {idx} char {char_idx}: expected '{exp_char}' ({ord(exp_char)}), got {extracted}"
                            )
                    # Check padding for remaining characters in word
                    for char_idx in range(len(exp_word), 8):
                        extracted = (word_bits >> (char_idx * 8)) & 0xFF
                        if extracted != ord(' '):
                            raise TestFailure(
                                f"Word {idx} padding char {char_idx}: expected space (0x20), got {extracted}"
                            )
            
            passed += 1
            cocotb.log.info(f"  PASS")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
