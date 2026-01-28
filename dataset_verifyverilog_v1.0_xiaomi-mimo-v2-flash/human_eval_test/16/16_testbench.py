import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

# Test constants
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

async def write_string(dut, s):
    """Write 8-char string to array, pad with nulls (0x00)"""
    chars = list(s.encode('ascii'))[:ARRAY_SIZE]
    chars += [0x00] * (ARRAY_SIZE - len(chars))
    for i, c in enumerate(chars):
        dut.str[i].value = clamp_to_width(c, DATA_WIDTH)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_distinct_chars(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_string, expected_distinct_count)
    test_cases = [
        ("", 0),
        ("abcde", 5),
        ("abcde" + "cade" + "CADE", 5),  # 'abcde' = 5 distinct
        ("aaaaAAAAaaaa", 1),
        ("Jerry jERRY JeRRRY", 5),  # J,e,R,r,y
        ("xyzXYZ", 3),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, *rest) in enumerate(test_cases):
        if isinstance(inp, int):
            inp = ""
        cocotb.log.info(f"Test {i+1}: '{inp}' -> {exp} distinct")
        try:
            await write_string(dut, inp)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Got {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
        if is_seq:
            await reset_dut(dut, cycles=1)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")