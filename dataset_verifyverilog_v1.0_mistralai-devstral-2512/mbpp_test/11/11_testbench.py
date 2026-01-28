import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string(dut, name, s):
    if len(s) > MAX_LEN:
        s = s[:MAX_LEN]
    for i in range(MAX_LEN):
        val = ord(s[i]) if i < len(s) else 0
        arr = getattr(dut, name)
        if isinstance(arr, list) or hasattr(arr, '__len__'):
            if i < len(arr):
                arr[i].value = clamp_to_width(val, DATA_WIDTH)
        else:
            break

async def read_string(dut, name, length):
    result = ""
    arr = getattr(dut, name)
    for i in range(min(length, MAX_LEN)):
        val = int(arr[i].value)
        result += chr(val)
    return result

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_remove_occ(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must have clock for sequential test")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("hello", "l", "heo", "remove middle l"),
        ("abcda", "a", "bcd", "remove first and last a"),
        ("PHP", "P", "H", "remove both ends P"),
        ("test", "x", "test", "char not found"),
        ("a", "a", "", "single char removal"),
        ("", "a", "", "empty string"),
        ("aaa", "a", "", "all same char"),
        ("abacaba", "a", "bcab", "multiple occurrences"),
    ]
    
    passed = failed = 0
    
    for i, (inp_str, ch, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input string
            await write_string(dut, 'input_str', inp_str)
            
            # Write character
            if has_signal(dut, 'target_char'):
                dut.target_char.value = clamp_to_width(ord(ch), DATA_WIDTH)
            
            # Write length
            if has_signal(dut, 'input_len'):
                dut.input_len.value = len(inp_str)
            
            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(200, units='ns')
            
            # Read output
            if has_signal(dut, 'output_len'):
                out_len = int(dut.output_len.value)
            else:
                out_len = len(expected)
            
            result = ""
            if has_signal(dut, 'output_str'):
                result = await read_string(dut, 'output_str', out_len)
            
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
