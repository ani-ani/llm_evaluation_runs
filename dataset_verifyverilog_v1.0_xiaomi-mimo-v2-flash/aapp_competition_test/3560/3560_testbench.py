import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 5
STRING_LEN = 16
QUERY_LEN = 16
NUM_BARBARIANS = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

def pack_string(s):
    if len(s) > STRING_LEN:
        raise ValueError(f"String '{s}' exceeds max length {STRING_LEN}")
    packed = 0
    for char in s:
        val = ord(char) - ord('a')
        if not (0 <= val < 26):
            raise ValueError(f"Invalid char {char}")
        packed = (packed << DATA_WIDTH) | val
    # Pad remaining bits with 0 (or 'a') if needed
    packed <<= (STRING_LEN - len(s)) * DATA_WIDTH
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def op_store_word(dut, idx, word):
    """Store word into barbarian index idx"""
    dut.mode.value = 0 # Mode 0 for storage
    dut.addr.value = idx
    packed = pack_string(word)
    dut.data.value = packed
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Assuming storage is combinational or takes 1 cycle
    await RisingEdge(dut.clk)

async def op_type1(dut, p_str):
    """Load query string P"""
    dut.mode.value = 1
    dut.op.value = 1 # Type 1
    dut.addr.value = 0
    packed = pack_string(p_str)
    dut.data.value = packed
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)

async def op_type2(dut, s_idx):
    """Query count for barbarian s_idx"""
    dut.mode.value = 1
    dut.op.value = 2 # Type 2
    dut.addr.value = s_idx
    dut.data.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_barbarians(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("This test requires a clocked module")

    # Test Case 1
    # 3 barbarians: 'a', 'bc', 'abc'
    # 3 rounds: 1 abca, 2 1, 2 3
    # Expected: 1, 1
    try:
        await op_store_word(dut, 0, "a")
        await op_store_word(dut, 1, "bc")
        await op_store_word(dut, 2, "abc")
        
        await op_type1(dut, "abca")
        
        await op_type2(dut, 0)
        res = int(dut.result.value)
        if res != 1:
            raise TestFailure(f"Test 1a: Expected 1, got {res}")
            
        await op_type2(dut, 2)
        res = int(dut.result.value)
        if res != 1:
            raise TestFailure(f"Test 1b: Expected 1, got {res}")
            
        cocotb.log.info("Test 1 Passed")
    except TestFailure as e:
        cocotb.log.error(f"FAIL: {e}")
        raise

    # Test Case 2
    # 7 barbarians (indices 0-6)
    # Words: abba, bbaa, b, bbaa, abba, a, ba
    # Rounds: 1 aaabbabbaab, 2 7 (idx 6 -> 'ba'), 1 baabaaa, 1 aabbbab, 2 3 (idx 2 -> 'b'), 1 aabba, 2 3
    # Expected outputs: 1, 3, 4 (based on provided sample output)
    # Note: Sample output provided is '1\n3\n4\n'. We match this.
    
    # Reset between tests or just overwrite
    # We can't clear state easily without reset, but we can overwrite the 16 slots
    words_2 = ["abba", "bbaa", "b", "bbaa", "abba", "a", "ba"]
    for i, w in enumerate(words_2):
        await op_store_word(dut, i, w)
    
    await op_type1(dut, "aaabbabbaab")
    
    # Query index 6 ('ba') -> should be in 'aaabbabbaab' -> yes (1)
    await op_type2(dut, 6)
    res = int(dut.result.value)
    if res != 1:
        raise TestFailure(f"Test 2a: Expected 1, got {res}")
        
    await op_type1(dut, "baabaaa")
    await op_type1(dut, "aabbbab")
    
    # Query index 2 ('b') -> check in 'aabbbab' -> yes (1)
    await op_type2(dut, 2)
    res = int(dut.result.value)
    if res != 1: # According to sample output '3' is the next answer, wait.
        # Let's trace Sample 2 output: 1, 3, 4
        # Round 1: 1 aaabbabbaab -> query
        # Round 2: 2 7 -> query 'ba' -> count=1 -> Output 1. Correct.
        # Round 3: 1 baabaaa -> query
        # Round 4: 1 aabbbab -> query
        # Round 5: 2 3 -> query barbarian 3 -> word 'b' (index 2? No, 1-based)
        # Input: Barbarians: 1:a, 2:bbaa, 3:b, ...
        # S=3 -> word is 'b'.
        # Queries shown so far: 'aaabbabbaab', 'baabaaa', 'aabbbab'
        # 'b' in 'aaabbabbaab'? Yes.
        # 'b' in 'baabaaa'? Yes.
        # 'b' in 'aabbbab'? Yes.
        # Total count = 3.
        # My test logic queried only 'aabbbab' (the latest one).
        # The problem asks for "Out of all the words I’ve shown you so far".
        # I must track cumulative counts.
        # So I cannot just overwrite query. I must accumulate.
        pass
        
    # Correct logic for Test 2 cumulative counts:
    # Reset DUT
    await reset_dut(dut)
    # Reload Barbarians
    for i, w in enumerate(words_2):
        await op_store_word(dut, i, w)
        
    # Round 1: Query "aaabbabbaab"
    await op_type1(dut, "aaabbabbaab")
    
    # Round 2: Query barbarian 6 (word 'ba') -> count 1
    await op_type2(dut, 6)
    res = int(dut.result.value)
    if res != 1:
        raise TestFailure(f"Test 2a (cumulative): Expected 1, got {res}")
        
    # Round 3: Query "baabaaa"
    await op_type1(dut, "baabaaa")
    
    # Round 4: Query "aabbbab"
    await op_type1(dut, "aabbbab")
    
    # Round 5: Query barbarian 2 (word 'b' - index 2 is 3rd word)
    # Input specifies S=3. Index is 2 (0-based).
    # Word is 'b'.
    # Matches in 'aaabbabbaab' (yes), 'baabaaa' (yes), 'aabbbab' (yes).
    await op_type2(dut, 2)
    res = int(dut.result.value)
    if res != 3:
        raise TestFailure(f"Test 2b (cumulative): Expected 3, got {res}")
        
    # Round 6: Query "aabba"
    await op_type1(dut, "aabba")
    
    # Round 7: Query barbarian 2 (word 'b')
    # Matches in all 4 queries shown so far.
    await op_type2(dut, 2)
    res = int(dut.result.value)
    if res != 4:
        raise TestFailure(f"Test 2c (cumulative): Expected 4, got {res}")
        
    cocotb.log.info("Test 2 Passed")
    
    raise TestFailure("All tests passed")
