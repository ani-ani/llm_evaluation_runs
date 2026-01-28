import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
DATA_WIDTH = 8
STRING_COUNT = 8
STRING_WIDTH = 8
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

def str_to_bytes(s, max_len=8):
    """Convert string to list of ASCII bytes, null-padded to max_len"""
    bytes_list = [ord(c) for c in s]
    # Null-terminate if shorter
    if len(bytes_list) < max_len:
        bytes_list.append(0)
    # Pad with zeros
    while len(bytes_list) < max_len:
        bytes_list.append(0)
    return bytes_list[:max_len]

async def write_string_array(dut, strings):
    """Write strings to dut.strings array"""
    for i, s in enumerate(strings):
        bytes_list = str_to_bytes(s, STRING_WIDTH)
        for j, b in enumerate(bytes_list):
            dut.strings[i][j].value = b

def pack_string(s, max_len=8):
    """Pack string into 64-bit value for easier comparison"""
    bytes_list = str_to_bytes(s, max_len)
    val = 0
    for i, b in enumerate(bytes_list):
        val |= b << (i * 8)
    return val

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_filter_by_prefix(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        {
            'desc': 'Empty input',
            'strings': [],
            'prefix': '',
            'exp_strings': [],
            'exp_count': 0,
            'exp_valid': 0
        },
        {
            'desc': 'Single match "abc" with prefix "a"',
            'strings': ['abc'],
            'prefix': 'a',
            'exp_strings': ['abc'],
            'exp_count': 1,
            'exp_valid': 1
        },
        {
            'desc': 'No match with prefix "xyz"',
            'strings': ['abc', 'def'],
            'prefix': 'xyz',
            'exp_strings': [],
            'exp_count': 0,
            'exp_valid': 0
        },
        {
            'desc': 'Multiple matches',
            'strings': ['abc', 'bcd', 'cde', 'array'],
            'prefix': 'a',
            'exp_strings': ['abc', 'array'],
            'exp_count': 2,
            'exp_valid': 0b1001
        },
        {
            'desc': 'Prefix longer than string',
            'strings': ['ab', 'abc'],
            'prefix': 'abc',
            'exp_strings': ['abc'],
            'exp_count': 1,
            'exp_valid': 0b10
        },
        {
            'desc': 'Full string match',
            'strings': ['test', 'te', 'test'],
            'prefix': 'test',
            'exp_strings': ['test', 'test'],
            'exp_count': 2,
            'exp_valid': 0b101
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {tc['desc']}")
        try:
            # Prepare input
            strings_input = tc['strings'][:STRING_COUNT]  # Limit to 8
            prefix = tc['prefix']
            valid_mask = (1 << len(strings_input)) - 1
            
            # Write strings to dut
            for si in range(STRING_COUNT):
                s = strings_input[si] if si < len(strings_input) else ''
                bytes_list = str_to_bytes(s, STRING_WIDTH)
                for ci, b in enumerate(bytes_list):
                    dut.strings[si][ci].value = b
            
            # Write valid mask
            if has_signal(dut, 'valid_strings'):
                dut.valid_strings.value = valid_mask
            
            # Write prefix
            prefix_bytes = str_to_bytes(prefix, STRING_WIDTH)
            for ci, b in enumerate(prefix_bytes):
                dut.prefix[ci].value = b
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                timeout = 0
                while timeout < MAX_CYCLES:
                    await RisingEdge(dut.clk)
                    timeout += 1
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
            else:
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.result_count.value):
                raise TestFailure("Result count undefined")
            result_count = int(dut.result_count.value)
            
            if result_count != tc['exp_count']:
                raise TestFailure(f"Expected count {tc['exp_count']}, got {result_count}")
            
            # Read valid mask
            if has_signal(dut, 'result_valid'):
                if not is_value_defined(dut.result_valid.value):
                    raise TestFailure("Result valid undefined")
                result_valid = int(dut.result_valid.value)
                if result_valid != tc['exp_valid']:
                    raise TestFailure(f"Expected valid {bin(tc['exp_valid'])}, got {bin(result_valid)}")
            
            # Read result strings
            result_strings = []
            for si in range(STRING_COUNT):
                valid = (result_valid >> si) & 1 if has_signal(dut, 'result_valid') else (si < result_count)
                if valid:
                    s_bytes = []
                    for ci in range(STRING_WIDTH):
                        b = int(dut.result_str[si][ci].value)
                        if b == 0:
                            break
                        s_bytes.append(chr(b))
                    result_strings.append(''.join(s_bytes))
            
            # Compare
            if len(result_strings) != len(tc['exp_strings']):
                raise TestFailure(f"Expected {len(tc['exp_strings'])} result strings, got {len(result_strings)}")
            
            for idx, (rs, es) in enumerate(zip(result_strings, tc['exp_strings'])):
                if rs != es:
                    raise TestFailure(f"Result string {idx}: expected '{es}', got '{rs}'")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

def check(candidate):
    # Python-style check for reference
    assert candidate([], 'john') == []
    assert candidate(['xxx', 'asd', 'xxy', 'john doe', 'xxxAAA', 'xxx'], 'xxx') == ['xxx', 'xxxAAA', 'xxx']
    print("Python reference check passed")

if __name__ == "__main__":
    # Run reference check
    def filter_by_prefix(strings, prefix):
        result = []
        for s in strings:
            if s.startswith(prefix):
                result.append(s)
        return result
    check(filter_by_prefix)
