import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_word(word_str, char_bits=5, width=16):
    """Pack ASCII char string into integer bit vector."""
    res = 0
    for i, c in enumerate(word_str[:width]):
        val = ord(c) - 97  # 'a'=0
        res |= (val & ((1 << char_bits) - 1)) << (i * char_bits)
    return res

# Configuration
CHAR_BITS = 5
MAX_LEN = 16
WORD_WIDTH = MAX_LEN * CHAR_BITS  # 80 bits
CLK_NS = 10
MAX_CYCLES = 1000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'search_start'):
        dut.search_start.value = 0
    if has_signal(dut, 'load_db'):
        dut.load_db.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_database(dut, db_words):
    dut._log.info("Loading database...")
    dut.load_db.value = 1
    for i, w in enumerate(db_words):
        dut.db_word_idx.value = i
        dut.db_word_in.value = pack_word(w)
        await RisingEdge(dut.clk)
    dut.load_db.value = 0
    await RisingEdge(dut.clk)

async def perform_search(dut, query_word):
    dut._log.info(f"Searching for: {query_word}")
    dut.query_word.value = pack_word(query_word)
    dut.search_start.value = 1
    await RisingEdge(dut.clk)
    dut.search_start.value = 0
    
    # Wait for done
    cycles = 0
    while True:
        if cycles > MAX_CYCLES:
            raise TestFailure(f"Timeout searching for {query_word}")
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        await RisingEdge(dut.clk)
        cycles += 1
    return int(dut.result.value)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_search_steps(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Data
    db = ["hobotnica", "robot", "hobi", "hobit", "robi"]
    queries = ["robi", "hobi", "hobit", "rakija"]
    expected = [12, 10, 16, 7]
    
    # Load DB
    await load_database(dut, db)
    
    passed = 0
    for q, exp in zip(queries, expected):
        try:
            result = await perform_search(dut, q)
            if result != exp:
                raise TestFailure(f"Query '{q}': Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
            
    if passed == len(queries):
        cocotb.log.info(f"All {passed} tests passed")