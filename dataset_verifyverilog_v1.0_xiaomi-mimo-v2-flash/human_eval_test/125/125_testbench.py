import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_split_words(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_string, expected_type, expected_val, description)
    # Type mapping: 00/01=word list (bitmask), 10/11=count (even/odd)
    # Val mapping: word list -> bitmask (bits set at word starts), count -> numeric value
    test_cases = [
        ("Hello world!", 0, 0b0000000000010001, "Two words, space"), # Bits 0 and 5 (H and w) start words
        ("Hello,world!", 1, 0b0000000000100001, "Two words, comma"), # Bits 0 and 6 (H and w)
        ("abcdef", 2, 3, "6 lowercase, 3 odd pos"), # a(0), b(1), c(2), d(3), e(4), f(5) -> b, d, f are odd -> 3
        ("aaabb", 2, 2, "5 lowercase, 2 odd pos"), # a,a,a,b,b -> pos b(1) -> 2 count (wait, a=0(0,2,4), b=1(1,3) -> 2 b's)
        ("aaaBb", 3, 1, "Mixed case, 1 odd pos lowercase"), # a,a,a,b -> pos b(1) -> 1
        ("", 2, 0, "Empty string"),
        ("Hello world,!", 0, 0b0000000000100001, "Space then comma"), # H, w
        ("Hello,Hello,world !", 0, 0b0000001000100001, "Commas and space") # H, H, w, !
    ]

    passed = 0
    failed = 0

    for i, (inp, exp_type, exp_val, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input '{inp}'")
        try:
            # Prepare inputs
            # ASCII to bytes
            bytes_arr = [ord(c) for c in inp]
            padded = bytes_arr + [0] * (16 - len(bytes_arr))
            
            # Write to dut (handle packed array if necessary, or individual)
            # Assuming char_data is packed array or separate signals
            if has_signal(dut, 'char_data'):
                # Check if it's an array
                try:
                    # Try packing if it's a single signal
                    dut.char_data.value = 0
                    for j, b in enumerate(padded):
                        dut.char_data.value |= (b << (j * 8))
                except (AttributeError, ValueError):
                    # Try individual bits/bytes if not packed
                    # If it's char_data[0]...
                    try:
                        for j in range(16):
                            getattr(dut, f'char_data[{j}]').value = padded[j]
                    except:
                         # Fallback: dut.arr style
                         for j, b in enumerate(padded):
                             if hasattr(dut, 'char_data') and hasattr(dut.char_data, '__getitem__'):
                                 dut.char_data[j].value = b
                             else:
                                 raise TestFailure("Cannot handle char_data format")
            
            dut.str_len.value = len(bytes_arr)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            res_type = int(dut.result_type.value)
            res_val = int(dut.result_val.value)
            
            # Verify
            # Type check: if exp_type is 0 or 1, result should be 0 or 1 (order of whitespace/comma)
            # If exp_type is 2 or 3, result should be 2 or 3 (even/odd)
            # Simple logic: just check the numeric value and type class (word vs count)
            # We defined exp_type: 0/1 for word, 2/3 for count
            
            is_word_result = (res_type in [0, 1])
            is_count_result = (res_type in [2, 3])
            exp_is_word = (exp_type in [0, 1])
            
            if exp_is_word != is_word_result:
                raise TestFailure(f"Result type mismatch. Expected {'word' if exp_is_word else 'count'}, got {'word' if is_word_result else 'count'}")
            
            if res_val != exp_val:
                 raise TestFailure(f"Expected val {exp_val} (binary {bin(exp_val)}), got {res_val} (binary {bin(res_val)})")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")