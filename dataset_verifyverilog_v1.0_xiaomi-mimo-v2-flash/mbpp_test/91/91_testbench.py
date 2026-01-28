import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

# Testbench config
DATA_WIDTH = 8
STR_LEN = 8
MAX_STRINGS = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper to write a string to a port (array of 8 chars)
async def write_string(dut, port_name, s):
    # Convert string to list of ASCII values, pad with 0
    vals = [ord(c) for c in s] + [0] * (STR_LEN - len(s))
    for i, v in enumerate(vals):
        getattr(dut, f"{port_name}_{i}").value = clamp_to_width(v, DATA_WIDTH)

# Helper to write entire list of strings
async def write_string_list(dut, str_list, num_strings):
    for i in range(MAX_STRINGS):
        if i < num_strings:
            s = str_list[i]
            await write_string(dut, f"str_{i}", s)
        else:
            # Pad with empty strings (null chars)
            for j in range(STR_LEN):
                getattr(dut, f"str_{i}_{j}").value = 0
    dut.num_strings.value = clamp_to_width(num_strings, 4)

# Helper to write substring
async def write_substring(dut, sub_str):
    vals = [ord(c) for c in sub_str] + [0] * (STR_LEN - len(sub_str))
    for i, v in enumerate(vals):
        getattr(dut, f"sub_str_{i}").value = clamp_to_width(v, DATA_WIDTH)
    dut.sub_len.value = clamp_to_width(len(sub_str), 4)

# Reset helper
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Wait for done signal
async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_substring(dut):
    # Check if sequential (has clk)
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (list of strings, substring, expected found)
    test_cases = [
        (['red', 'black', 'white', 'green', 'orange'], 'ack', True),
        (['red', 'black', 'white', 'green', 'orange'], 'abc', False),
        (['red', 'black', 'white', 'green', 'orange'], 'ange', True),
        (['hello', 'world'], 'ell', True),
        (['test', 'case'], 'xyz', False),
        (['cat', 'dog', 'bird'], 'bird', True),
    ]
    
    passed = failed = 0
    
    for idx, (str_list, sub_str, expected) in enumerate(test_cases):
        num_strings = len(str_list)
        cocotb.log.info(f"Test {idx+1}: List={str_list}, Substring='{sub_str}', Expected={expected}")
        
        try:
            await write_string_list(dut, str_list, num_strings)
            await write_substring(dut, sub_str)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.found.value):
                raise TestFailure("Found signal undefined")
            
            result = int(dut.found.value) == 1
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
