import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string_packed(dut, s):
    # Pack string into 16 bytes (128 bits)
    bytes_list = [ord(c) for c in s] + [0] * (16 - len(s))
    packed_val = 0
    for i, b in enumerate(bytes_list):
        packed_val |= (b & 0xFF) << (8 * (15 - i)) # Big-endian byte order for MSB first
    dut.str.value = packed_val
    dut.len.value = len(s)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_robber_language(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases based on description
    # car -> 1 (length 3)
    # cocar -> 2 (length 3 or 1? 'cocar' is 5 chars. 
    #   c o c a r -> 'c'->c, 'o'->o, 'c'->c, 'a'->a, 'r'->r -> original "car"
    #   c o c a r -> 'c'->coc, 'a'->a, 'r'->r -> original "car" (wait, cocar length 5)
    #   Actually, input "cocar" (length 5). 
    #   Possibility 1: c (missed) + o (vowel) + c (missed) + a + r -> original "car"
    #   Possibility 2: c (missed) + o (vowel) + c (transformed) -> wait, coc is 3 chars. c(0) o(1) c(2). If c is transformed, it's coc. 
    #   But we need to parse the whole string.
    #   Input: c o c a r
    #   Path 1: 'c' (1) + 'o' (1) + 'c' (1) + 'a' (1) + 'r' (1) -> original "car" (len 3)
    #   Path 2: 'c' (1) + 'o' (1) + 'c' (3) is invalid because 'coc' is 3 chars, leaving 'ar' (2 chars) which doesn't fit 'coc'...
    #   Wait, 'coc' is the transformation of 'c'. Input is "cocar".
    #   Parse 'cocar':
    #   1. c (missed) -> orig 'c', remaining "ocar"
    #      o (vowel) -> orig 'o', remaining "car"
    #      c (missed) -> orig 'c', remaining "ar"
    #      a -> 'a', remaining "r"
    #      r -> 'r', remaining "". Valid. Original "car".
    #   2. c (missed) -> orig 'c', remaining "ocar"
    #      o (vowel) -> orig 'o', remaining "car"
    #      c (transformed) -> 'coc' consumes 3 chars. Input remaining "ar". Wait, 'coc' is 3 chars. c(0), o(1), c(2).
    #      Input indices 0,1,2. Remaining indices 3,4 ('a','r').
    #      'a' -> 'a', remaining 'r'.
    #      'r' -> 'r'. Valid. Original "cor"? No, wait. 
    #      Original letters: c, o, c, a, r -> that's 5 letters. 
    #      Wait, the transformation replaces a consonant with 3 letters. 
    #      If we take 'coc' (indices 0,1,2) as the transformation of 'c', then the original letter is 'c'. 
    #      So original: c (from coc) + o (from o) + ? remaining is "ar" (indices 3,4).
    #      'a' -> 'a'. 'r' -> 'r'. 
    #      Original: c, o, a, r -> "coar". 
    #      Does "coar" transform to "cocar"?
    #      c -> coc. o -> o. a -> a. r -> r. -> "cooar". No.
    #      Okay, let's look at the example output. "cocar" -> 2.
    #      The string "cocar" is 5 chars.
    #      Possibility 1: c (1 char) + o (1) + c (1) + a (1) + r (1) -> Original "car". 
    #         Transformation: car -> c->c, a->a, r->r -> "car". Wait, "car" is the original.
    #         If Edvin was drunk, he might have missed transforming consonants.
    #         Original "car". Correct Robber: "coc a or" -> "cocoar"?
    #         No, 'c' -> coc, 'a' -> a, 'r' -> ror. -> "cocoaror".
    #         Input is "cocar" (5 chars).
    #         If original is "car" (3 chars). 
    #         Option A: Edvin missed all consonants: c->c, a->a, r->r -> "car" (3 chars). Input is 5.
    #         Option B: Edvin missed some.
    #         Let's try to parse "cocar" into original letters.
    #         Index 0: 'c'.
    #         1. 'c' is consonant. Could be original 'c' (if missed). Remaining "ocar".
    #         2. 'c' is consonant. Could be start of 'coc' (if transformed). Remaining "ar".
    #         Path 1: Pick 'c' (missed). Current original: 'c'. Remaining "ocar".
    #            Index 0 of "ocar" is 'o' (vowel). Must be original 'o'. Remaining "car".
    #            Index 0 of "car" is 'c' (consonant).
    #            1a. Pick 'c' (missed). Remaining "ar".
    #               'a' (vowel) -> 'a'. Remaining "r".
    #               'r' (consonant) -> 'r' (missed). Remaining "".
    #               Original: c, o, c, a, r -> "cocar". Wait, if all were missed, the result is just the input.
    #               But the problem says "Edvin sometimes missed to transform some consonants". 
    #               If he missed, the output is just the consonant. 
    #               If he did it right, the output is c-o-c.
    #               Input "cocar". 
    #               Case 1: Input is exactly the original (all missed). Original "cocar".
    #                 Check: "cocar" -> Robber language? 
    #                 c -> coc, o -> o, c -> coc, a -> a, r -> ror. -> "coco coc a ror" -> "cocococaror".
    #                 So "cocar" is not a valid transformation of "cocar".
    #               Case 2: Input is partial transformation.
    #               Let's re-read example. "cocar" -> 2.
    #               Let's look at "car" -> 1.
    #               Input "car" (length 3).
    #               'c' (consonant).
    #               1. 'c' (missed) -> orig 'c', rem "ar".
    #                  'a' (vowel) -> 'a', rem "r".
    #                  'r' (consonant) -> 'r' (missed), rem "".
    #                  Original "car".
    #               2. 'c' (transformed) -> 'coc', rem "ar".
    #                  'a' -> 'a', rem "r".
    #                  'r' -> 'r' (missed), rem "".
    #                  Original "car".
    #                  Wait, if 'c' is transformed, it becomes 'coc'. 
    #                  If input is "car", 'c' cannot be 'coc' because 'coc' is length 3, leaving "ar".
    #                  So only 1 way.
    #               Now "cocar" -> 2.
    #               Input "cocar" (length 5).
    #               Index 0: 'c'.
    #               1. 'c' missed -> orig 'c', rem "ocar".
    #                  Index 0 'o' -> orig 'o', rem "car".
    #                  Index 0 'c'.
    #                  1a. 'c' missed -> orig 'c', rem "ar".
    #                      'a' -> 'a', rem "r".
    #                      'r' -> 'r', rem "". Valid. Original "cocar". (Wait, input "cocar" -> "cocar" if all missed?)
    #                      Yes, if all consonants are missed, the output string is identical to input.
    #                      So "cocar" is a possible original.
    #                  1b. 'c' transformed -> 'coc', rem "ar". 
    #                      'a' -> 'a', rem "r".
    #                      'r' -> 'r', rem "". Valid. Original "cocar". 
    #                      Wait, input "cocar". 
    #                      Path 1b: c(0) [missed] + o(1) [vowel] + coc(2,3,4) [transformed c]. 
    #                      Wait, indices 2,3,4 are 'c', 'a', 'r'. 
    #                      'coc' is 'c', 'o', 'c'. 
    #                      Input[2] is 'c'. Input[3] is 'a'. Input[4] is 'r'.
    #                      So 'coc' does not match indices 2,3,4.
    #               Let's try path 2 at index 0.
    #               2. 'c' transformed -> 'coc', rem "ar" (indices 3,4).
    #                  Index 3: 'a' -> 'a', rem "r" (index 4).
    #                  Index 4: 'r' -> 'r', rem "". Valid. Original "car".
    #                  Original: c (from coc) + a + r = "car".
    #                  Check: "car" -> Robber? c->coc, a->a, r->ror -> "coc a ror" -> "cocaror".
    #                  Edvin wrote "cocar". 
    #                  So "car" is a valid original for "cocar".
    #               So we have 2 ways: Original "cocar" and Original "car".
    #               Wait, "cocar" -> "cocar" (all missed). 
    #               "cocar" -> "car" (c->coc, a->a, r->r).
    #               Yes, 2 ways.
    
    test_cases = [
        ("car", 1),
        ("cocar", 2),
        ("cocaror", 4),
        ("a", 1),
        ("b", 1),
        ("coc", 2),
        ("", 1)
    ]
    
    for i, (inp_str, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input='{inp_str}' Expected={exp}")
        try:
            if is_seq:
                await reset_dut(dut)
                await write_string_packed(dut, inp_str)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await write_string_packed(dut, inp_str)
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
