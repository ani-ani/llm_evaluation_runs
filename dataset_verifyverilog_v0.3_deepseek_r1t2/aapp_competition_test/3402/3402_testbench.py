import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPER FUNCTIONS
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)): return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0: return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# CONFIGURATION
DATA_WIDTH = 8
MAX_S_LEN = 16
MAX_QUERIES = 8
CLK_PERIOD_NS = 10

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_en.value = 0
    dut.query_load_en.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_data(dut, s_str, T_map):
    """Load S and T strings via load_en interface."""
    # Load S
    for i, c in enumerate(s_str):
        dut.load_en.value = 1
        dut.load_addr.value = i
        dut.load_data.value = ord(c)
        await RisingEdge(dut.clk)
    # Load T - pack length and position into load_len
    for char, t_str in T_map.items():
        char_idx = ord(char) - ord('a')
        for pos, c in enumerate(t_str):
            dut.load_en.value = 1
            dut.load_addr.value = 16 + char_idx
            dut.load_data.value = ord(c)
            # Pack length (high nibble) and position (low nibble)
            dut.load_len.value = (len(t_str) << 4) | pos
            await RisingEdge(dut.clk)
    dut.load_en.value = 0
    # Mark completion
    dut.load_en.value = 1
    dut.load_addr.value = 41
    await RisingEdge(dut.clk)
    dut.load_en.value = 0

async def load_queries(dut, queries):
    """Load query positions."""
    for i, pos in enumerate(queries):
        dut.query_load_en.value = 1
        dut.query_addr.value = i
        dut.query_pos.value = pos
        await RisingEdge(dut.clk)
    dut.query_load_en.value = 0

@cocotb.test(timeout_time=15000, timeout_unit="ms")
async def test_password_recovery(dut):
    """Test password recovery with scaled inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test 1: K=1
    dut._log.info("Test 1: K=1, S='abca', queries=[1,8]")
    S = "abca"
    T_map = {
        'a': 'bc', 'b': 'cd', 'c': 'da', 'd': 'dd', 'e': 'ee',
        'f': 'ff', 'g': 'gg', 'h': 'hh', 'i': 'ii', 'j': 'jj',
        'k': 'kk', 'l': 'll', 'm': 'mm', 'n': 'nn', 'o': 'oo',
        'p': 'pp', 'q': 'qq', 'r': 'rr', 's': 'ss', 't': 'tt',
        'u': 'uu', 'v': 'vv', 'w': 'ww', 'x': 'xx', 'y': 'yy', 'z': 'zz'
    }
    queries = [1, 8]
    expected = ['b', 'c']
    
    await load_data(dut, S, T_map)
    await load_queries(dut, queries)
    dut.K.value = 1
    dut.M.value = len(queries)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect results
    results = []
    for _ in range(len(queries)):
        timeout = 0
        while timeout < 1000:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                break
            timeout += 1
        else:
            raise TestFailure("Timeout waiting for result")
        
        if not is_value_defined(dut.result_char.value):
            raise TestFailure("Result char undefined")
        results.append(chr(int(dut.result_char.value)))
    
    for i, (r, e) in enumerate(zip(results, expected)):
        if r != e:
            raise TestFailure(f"Test 1.{i}: expected '{e}', got '{r}'")
        dut._log.info(f"  Position {queries[i]} = '{r}' [OK]")
    
    # Test 2: K=2
    dut._log.info("Test 2: K=2, S='ab', queries=[1,8]")
    await reset_dut(dut)
    
    S = "ab"
    T_map['a'] = 'ba'
    T_map['b'] = 'ab'
    queries = [1, 8]
    expected = ['a', 'b']
    
    await load_data(dut, S, T_map)
    await load_queries(dut, queries)
    dut.K.value = 2
    dut.M.value = len(queries)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = []
    for _ in range(len(queries)):
        timeout = 0
        while timeout < 1000:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                break
            timeout += 1
        else:
            raise TestFailure("Timeout waiting for result")
        
        results.append(chr(int(dut.result_char.value)))
    
    for i, (r, e) in enumerate(zip(results, expected)):
        if r != e:
            raise TestFailure(f"Test 2.{i}: expected '{e}', got '{r}'")
        dut._log.info(f"  Position {queries[i]} = '{r}' [OK]")
    
    dut._log.info("All tests passed!")
