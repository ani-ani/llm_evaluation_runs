import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
DATA_WIDTH = 8
ARRAY_SIZE = 64
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

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

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout waiting for done")

# String processing helpers
def pack_string(s):
    # Pack string into 512-bit integer (64 bytes)
    val = 0
    for i, ch in enumerate(s):
        val |= (ord(ch) << (8 * i))
    return val

def unpack_word(word_vec):
    # Extract 16-byte word from vector
    s = ""
    for i in range(16):
        byte = (word_vec >> (8 * i)) & 0xFF
        if byte == 0: break
        s += chr(byte)
    return s

def count_consonants(word):
    vowels = set('aeiouAEIOU')
    count = 0
    for ch in word:
        if ch.isalpha() and ch not in vowels:
            count += 1
    return count

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_select_words(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("Mary had a little lamb", 4, ["little"]),
        ("Mary had a little lamb", 3, ["Mary", "lamb"]),
        ("simple white space", 2, []),
        ("Hello world", 4, ["world"]),
        ("Uncle sam", 3, ["Uncle"]),
        ("", 4, []),
        ("a b c d e f", 1, ["b", "c", "d", "f"]),
        ("Testing edge cases", 4, ["edge"]),
        ("Short", 100, [])
    ]

    total_passed = 0
    total_failed = 0

    for idx, (input_str, n_val, expected_words) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx+1}: '{input_str}' n={n_val}")
        
        try:
            # Prepare inputs
            packed_str = pack_string(input_str)
            str_len = len(input_str)
            
            # Drive inputs
            dut.input_string.value = packed_str
            dut.n.value = n_val
            dut.len.value = str_len
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Collect results
            found_words = []
            max_wait = 500
            
            for _ in range(max_wait):
                await RisingEdge(dut.clk)
                
                # Check for result found
                if has_signal(dut, 'result_found') and is_value_defined(dut.result_found.value):
                    if int(dut.result_found.value) == 1:
                        if has_signal(dut, 'result_word') and is_value_defined(dut.result_word.value):
                            word_val = int(dut.result_word.value)
                            word_str = unpack_word(word_val)
                            found_words.append(word_str)
                            cocotb.log.info(f"  Found word: '{word_str}'")
                        else:
                            raise TestFailure("result_found high but result_word undefined")
                
                # Check for done
                if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                    if int(dut.done.value) == 1:
                        break
            else:
                raise TestFailure("Did not reach done state")
            
            # Verify
            if found_words != expected_words:
                raise TestFailure(f"Expected {expected_words}, got {found_words}")
            
            total_passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} FAILED: {e}")
            total_failed += 1
            
    if total_failed > 0:
        raise TestFailure(f"{total_failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {total_passed} tests passed")
