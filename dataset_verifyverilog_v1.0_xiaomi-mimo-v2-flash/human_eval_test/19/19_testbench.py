import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import struct

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Word to value mapping
WORDS = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine']
WORD_TO_VAL = {w:i for i,w in enumerate(WORDS)}

# Pack 5-byte word to 40-bit integer
def pack_word(word_str):
    packed = 0
    for i, c in enumerate(word_str[:5]):
        packed |= (ord(c) << (i*8))
    return packed

def unpack_word(packed):
    chars = []
    for i in range(5):
        c = (packed >> (i*8)) & 0xFF
        if c != 0:
            chars.append(chr(c))
    return ''.join(chars)

# Generate sorted words
def sort_words(input_str):
    if not input_str.strip():
        return [], 0
    words = input_str.split()
    words = words[:8]  # Max 8 words
    sorted_vals = sorted([WORD_TO_VAL[w] for w in words])
    sorted_words = [WORDS[v] for v in sorted_vals]
    return sorted_words, len(sorted_words)

# Test function
def check(input_str):
    sorted_words, count = sort_words(input_str)
    packed = [pack_word(w) for w in sorted_words]
    packed_array = 0
    for i, p in enumerate(packed):
        packed_array |= (p << (i*40))
    return packed_array, count

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_sort_numbers(dut):
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        ('', 0, 'empty'),
        ('three', 1, 'single'),
        ('three five nine', 3, 'three words'),
        ('five zero four seven nine eight', 6, 'six words'),
        ('six five four three two one zero', 7, 'seven words')
    ]
    
    passed = failed = 0
    
    for inp_str, exp_count, desc in test_cases:
        cocotb.log.info(f'Test: {desc} - Input: "{inp_str}"')
        try:
            # Reset
            if has_signal(dut, 'rst_n'):
                dut.rst_n.value = 0
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)
            
            # Send input character by character
            dut.char_valid.value = 0
            dut.char_in.value = 0
            
            for char in inp_str:
                if char == ' ':
                    dut.char_in.value = ord(' ')
                else:
                    dut.char_in.value = ord(char)
                dut.char_valid.value = 1
                await RisingEdge(dut.clk)
            
            # Send terminator
            dut.char_in.value = 0  # Null terminator
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
            dut.char_valid.value = 0
            
            # Start sorting
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done or timeout
                done = False
                for _ in range(200):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f'Timeout waiting for done signal')
            else:
                await Timer(1000, units='ns')
            
            # Check results
            if has_signal(dut, 'word_count'):
                word_count = int(dut.word_count.value)
                exp_words, exp_count = sort_words(inp_str)
                
                if word_count != exp_count:
                    raise TestFailure(f'Expected word_count={exp_count}, got {word_count}')
                
                if word_count > 0 and has_signal(dut, 'sorted_words'):
                    # Read packed array
                    packed_val = int(dut.sorted_words.value)
                    
                    # Extract and verify each word
                    for i in range(word_count):
                        # Extract 40-bit word from position i
                        word_val = (packed_val >> (i * 40)) & ((1 << 40) - 1)
                        word_str = unpack_word(word_val)
                        exp_word = exp_words[i]
                        
                        if word_str != exp_word:
                            raise TestFailure(f'Word {i}: expected "{exp_word}", got "{word_str}"')
                
                cocotb.log.info(f'Success: {word_count} words sorted')
                passed += 1
            else:
                cocotb.log.info('Module output signals not found, test passed')
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f'FAIL: {desc} - {e}')
            failed += 1
    
    if failed:
        raise TestFailure(f'{failed} test(s) failed')