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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Constants
DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 1000
VOWELS = {'a': 0x61, 'e': 0x65, 'i': 0x69, 'o': 0x6F, 'u': 0x75}

def is_vowel(c):
    return c in VOWELS.values()

def count_vowels_python(s):
    res = 0
    vow_list = list(VOWELS.values())
    s_padded = s.ljust(MAX_LEN, ' ').encode('ascii')
    for i in range(MAX_LEN):
        if s_padded[i] == 0x20:  # space (end of string)
            break
    # Process only actual length
    actual_len = len(s)
    for idx in range(0, actual_len):
        char = s_padded[idx]
        if char in vow_list:
            continue
        if idx > 0 and s_padded[idx-1] in vow_list:
            res += 1
        elif idx < actual_len - 1 and s_padded[idx+1] in vow_list:
            res += 1
    return res

async def write_string(dut, s):
    # Convert to bytes, pad with spaces
    encoded = s.encode('ascii').ljust(MAX_LEN, ' ').encode('ascii')
    for i in range(MAX_LEN):
        # Access array via index
        if has_signal(dut, f'str_{i}'):
            getattr(dut, f'str_{i}').value = encoded[i]
        else:
            dut.str[i].value = encoded[i]

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_count_vowels_neighbors(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: still need to wait for propagation
        pass
    
    test_cases = [
        ('bestinstareels', 7, "Test 1: bestinstareels"),
        ('partofthejourneyistheend', 12, "Test 2: partofthejourneyistheend"),
        ('amazonprime', 5, "Test 3: amazonprime"),
        ('a', 0, "Edge: single vowel"),
        ('b', 0, "Edge: single consonant"),
        ('ab', 0, "Edge: two chars ab"),
        ('ba', 0, "Edge: two chars ba"),
        ('abc', 1, "Edge: three chars abc"),
    ]
    
    passed = failed = 0
    
    for i, (inp_str, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input string
            await write_string(dut, inp_str)
            
            if is_seq:
                # Trigger processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # For combinational, wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Output 'result' not found")
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            # Calculate expected using Python function
            expected = count_vowels_python(inp_str)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")