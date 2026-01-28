import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, STR_LEN, MAX_STRINGS, CLK_NS, MAX_CYCLES = 8, 16, 8, 10, 256

# MANDATORY HELPERS

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

# ARRAY WRITING

def pack_string_to_bits(s, max_len=STR_LEN):
    bits = 0
    s_bytes = s.encode('ascii') if isinstance(s, str) else s
    for i in range(min(len(s_bytes), max_len)):
        bits |= s_bytes[i] << (i * 8)
    return bits

async def write_strings_array(dut, strings):
    """Write strings to dut.strings array elements."""
    if has_signal(dut, 'strings'):
        for i, s in enumerate(strings):
            if i < MAX_STRINGS:
                packed = pack_string_to_bits(s, STR_LEN)
                dut.strings[i].value = clamp_to_width(packed, STR_LEN * 8)
    else:
        # Individual ports strings_0, strings_1...
        for i, s in enumerate(strings):
            if i < MAX_STRINGS:
                packed = pack_string_to_bits(s, STR_LEN)
                port = getattr(dut, f'strings_{i}')
                port.value = clamp_to_width(packed, STR_LEN * 8)

async def write_substring(dut, substring):
    """Write substring to dut.substring port."""
    packed = pack_string_to_bits(substring, STR_LEN)
    if has_signal(dut, 'substring'):
        dut.substring.value = clamp_to_width(packed, STR_LEN * 8)
    else:
        # Handle as packed array or individual bits
        dut.substr.value = clamp_to_width(packed, STR_LEN * 8)

async def read_strings_array(dut, expected_count):
    """Read filtered strings from output."""
    result = []
    # Try reading packed result array first
    if has_signal(dut, 'result_strings'):
        for i in range(expected_count):
            if i < MAX_STRINGS:
                packed = int(dut.result_strings[i].value)
                result.append(packed)
    else:
        # Try individual result_string_0, result_string_1...
        for i in range(expected_count):
            if i < MAX_STRINGS:
                port = getattr(dut, f'result_string_{i}')
                packed = int(port.value)
                result.append(packed)
    return result

def bits_to_string(bits, max_len=STR_LEN):
    s = []
    for i in range(max_len):
        byte_val = (bits >> (i * 8)) & 0xFF
        if byte_val != 0:  # Non-null character
            s.append(chr(byte_val))
        else:
            break
    return ''.join(s)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_filter_by_substring(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([], 'a', []),
        (['abc', 'bacd', 'cde', 'array'], 'a', ['abc', 'bacd', 'array']),
        (['xxx', 'asd', 'xxy', 'john doe', 'xxxAAA', 'xxx'], 'xxx', ['xxx', 'xxxAAA', 'xxx']),
        (['xxx', 'asd', 'aaaxxy', 'john doe', 'xxxAAA', 'xxx'], 'xx', ['xxx', 'aaaxxy', 'xxxAAA', 'xxx']),
        (['grunt', 'trumpet', 'prune', 'gruesome'], 'run', ['grunt', 'prune'])
    ]
    
    passed = failed = 0
    
    for i, (strings, substring, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Filtering {len(strings)} strings for '{substring}'")
        try:
            # Prepare input (pad to 8 strings with empty strings)
            padded_strings = strings + [''] * (MAX_STRINGS - len(strings))
            
            # Write inputs
            await write_strings_array(dut, padded_strings)
            await write_substring(dut, substring)
            
            if is_seq:
                # Set up len
                if has_signal(dut, 'str_len'):
                    dut.str_len.value = len(substring)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                # Read result count
                if has_signal(dut, 'result_count'):
                    result_count = int(dut.result_count.value)
                else:
                    result_count = len(expected)
                    
                # Read result strings
                packed_results = await read_strings_array(dut, min(result_count, MAX_STRINGS))
                result_strings = [bits_to_string(p, STR_LEN) for p in packed_results]
                
            else:
                await Timer(100, units='ns')
                # For combinational, assume direct outputs
                packed_results = await read_strings_array(dut, len(expected))
                result_strings = [bits_to_string(p, STR_LEN) for p in packed_results]
                result_count = len(result_strings)
            
            # Verify
            if result_count != len(expected):
                raise TestFailure(f"Count mismatch: expected {len(expected)}, got {result_count}")
            
            for exp_str, got_packed in zip(expected, packed_results):
                got_str = bits_to_string(got_packed, STR_LEN)
                if got_str != exp_str:
                    raise TestFailure(f"String mismatch: expected '{exp_str}', got '{got_str}'")
            
            cocotb.log.info(f"  PASS: {len(expected)} strings matched")
            passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")