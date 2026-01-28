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

# Helper to convert string to 128-bit value (16 bytes)
def str_to_bytes(s, max_len=16):
    val = 0
    for i, ch in enumerate(s[:max_len]):
        val |= (ord(ch) & 0xFF) << (8 * (15 - i))
    return val

def bytes_to_str(val, max_len=16):
    chars = []
    for i in range(max_len):
        byte = (val >> (8 * (15 - i))) & 0xFF
        if byte == 0:
            break
        chars.append(chr(byte))
    return ''.join(chars)

def get_string_length(val):
    for i in range(16):
        byte = (val >> (8 * (15 - i))) & 0xFF
        if byte == 0:
            return i
    return 16

async def write_strings(dut, strings, max_count=8):
    for i in range(max_count):
        val = 0
        if i < len(strings):
            val = str_to_bytes(strings[i])
        dut.strings[i].value = val
    dut.valid_count.value = len(strings)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_sorted_list_sum(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        (['aa', 'a', 'aaa'], ['aa']),
        (['school', 'AI', 'asdf', 'b'], ['AI', 'asdf', 'school']),
        (['d', 'b', 'c', 'a'], []),
        (['d', 'dcba', 'abcd', 'a'], ['abcd', 'dcba']),
        (['AI', 'ai', 'au'], ['AI', 'ai', 'au']),
        (['a', 'b', 'b', 'c', 'c', 'a'], []),
        (['aaaa', 'bbbb', 'dd', 'cc'], ['cc', 'dd', 'aaaa', 'bbbb'])
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input={inp}, Expected={exp}")
        try:
            await write_strings(dut, inp)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(200, units='ns')
            
            if not is_value_defined(dut.result_count.value):
                raise TestFailure("Result count undefined")
            
            result_count = int(dut.result_count.value)
            result_strings = []
            
            for j in range(8):
                if not is_value_defined(dut.result[j].value):
                    raise TestFailure(f"Result string {j} undefined")
                val = int(dut.result[j].value)
                s = bytes_to_str(val)
                if s:  # Only add non-empty strings
                    result_strings.append(s)
            
            # Result strings should match length of result_count
            if len(result_strings) != result_count:
                raise TestFailure(f"Result count mismatch: count={result_count}, got {len(result_strings)} strings")
            
            # Check if result matches expected
            if result_strings != exp:
                raise TestFailure(f"Expected {exp}, got {result_strings}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")