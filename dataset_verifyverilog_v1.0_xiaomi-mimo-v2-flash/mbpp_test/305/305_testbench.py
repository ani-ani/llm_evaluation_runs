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

def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    # We assume reset is async, so just wait for cycles
    # In test, we might need to handle it.
    # For simplicity, reset active low, pulse it.
    dut.rst_n.value = 0
    for _ in range(cycles): yield RisingEdge(dut.clk)
    dut.rst_n.value = 1
    yield RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Function to pack strings into 128-bit vector
# 16 bytes per string, 8 strings
# Python string -> bytes -> integer
# 16 chars, padded with nulls (0) if shorter
# MSB first or LSB first? Typically LSB is index 0.
# Let's assume index 0 is character 0 (leftmost).
# pack: word 0 is lower 128 bits? Or split?
# 8 strings * 128 bits = 1024 bits total.
# Let's assume `words_in[1023:0]`. `words_in[127:0]` is string 0.
# Char 0 (index 0) is bits [7:0], Char 1 is [15:8], ..., Char 15 is [127:120].

def pack_string(s):
    val = 0
    s_bytes = s.encode('ascii')
    for i in range(16):
        b = s_bytes[i] if i < len(s_bytes) else 0
        val |= b << (i * 8)
    return val

def pack_words(words):
    # words is list of 8 strings
    packed = 0
    for i in range(8):
        w = words[i] if i < len(words) else ""
        w_val = pack_string(w)
        packed |= w_val << (i * 128)
    return packed

def unpack_word(val):
    # Extract string from 128-bit value
    s = ""
    for i in range(16):
        byte = (val >> (i * 8)) & 0xFF
        if byte == 0: break
        s += chr(byte)
    return s

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_start_with_p(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases adapted for HDL constraints
    # Case 1: "Python PHP" in first string
    # Case 2: "Python Programming"
    # Case 3: "Pqrst Pqr"
    
    test_cases = [
        (["Python PHP", "Java"], "Python", "PHP"),
        (["Programming", "Python Programming"], "Python", "Programming"),
        (["Pqrst Pqr", "qrstuv"], "Pqrst", "Pqr"),
        (["No Match Here", "Just Java"], None, None),
        (["P1 P2 P3", ""], "P1", "P2")
    ]
    
    passed = 0
    failed = 0
    
    for i, (words_in, exp_w1, exp_w2) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        try:
            # Pack inputs
            packed = pack_words(words_in)
            
            # Send inputs
            dut.words_in.value = packed
            await RisingEdge(dut.clk)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, 2000)
            
            # Check valid and outputs
            valid = int(dut.valid.value) if is_value_defined(dut.valid.value) else 0
            
            if exp_w1 is None:
                # Expect no match
                if valid != 0:
                    raise TestFailure(f"Expected no match (valid=0), but got valid={valid}")
            else:
                if valid != 1:
                    raise TestFailure(f"Expected valid=1, got {valid}")
                
                w1_val = int(dut.word1_out.value)
                w2_val = int(dut.word2_out.value)
                
                w1_str = unpack_word(w1_val)
                w2_str = unpack_word(w2_val)
                
                if w1_str != exp_w1 or w2_str != exp_w2:
                    raise TestFailure(f"Mismatch: Expected ('{exp_w1}', '{exp_w2}'), got ('{w1_str}', '{w2_str}')")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"Test Case {i+1} FAILED: {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")