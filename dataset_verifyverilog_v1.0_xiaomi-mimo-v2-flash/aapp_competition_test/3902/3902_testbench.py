import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import string

DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 300

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

def to_ascii(s):
    return [ord(c) for c in s]

def pack_suffix(suffix_str):
    """Pack suffix string into 32-bit value"""
    chars = [ord(c) for c in suffix_str]
    result = 0
    for i, c in enumerate(chars):
        result |= (c & 0xFF) << (i * 8)
    return result

def decode_suffix(packed_value, length):
    """Decode 32-bit packed suffix to string"""
    chars = []
    for i in range(length):
        char = (packed_value >> (i * 8)) & 0xFF
        chars.append(chr(char))
    return ''.join(chars)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_reberland_suffixes(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Helper to write string to array
    async def write_string(dut, s):
        if has_signal(dut, 's_ascii'):
            ascii_vals = to_ascii(s)
            for i in range(MAX_LEN):
                if i < len(ascii_vals):
                    dut.s_ascii[i].value = ascii_vals[i]
                else:
                    dut.s_ascii[i].value = 0
        if has_signal(dut, 's_len'):
            dut.s_len.value = len(s)
    
    # Helper to wait for done
    async def wait_for_done():
        if not is_seq:
            await Timer(100, units='ns')
            return True
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
    
    # Helper to read results
    def read_results():
        if not has_signal(dut, 'result_count'):
            return [], []
        count = int(dut.result_count.value)
        suffixes = []
        lengths = []
        for i in range(min(count, 16)):
            packed = int(dut.result_suffixes[i].value)
            length = int(dut.result_len[i].value)
            if length == 1:  # length 2
                suffix = decode_suffix(packed, 2)
            elif length == 2:  # length 3
                suffix = decode_suffix(packed, 3)
            else:
                continue
            suffixes.append(suffix)
            lengths.append(length)
        return suffixes, lengths
    
    # Test cases
    test_cases = [
        ("abacabaca", {"aca", "ba", "ca"}),
        ("abaca", set()),
        ("gzqgchv", {"hv"}),
        ("aaaaax", set()),
        ("aaaaaxx", {"xx"}),
        ("aaaaaxyz", {"xyz", "yz"}),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_set) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: s='{input_str}' (len={len(input_str)})")
        
        try:
            # Write input
            await write_string(dut, input_str)
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done()
            else:
                await Timer(100, units='ns')
            
            # Read results
            result_suffixes, _ = read_results()
            result_set = set(result_suffixes)
            
            cocotb.log.info(f"  Expected: {sorted(expected_set)}")
            cocotb.log.info(f"  Got: {sorted(result_set)}")
            
            # Verify
            if result_set != expected_set:
                raise TestFailure(
                    f"Mismatch: expected {sorted(expected_set)}, got {sorted(result_set)}"
                )
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests
        if is_seq and i < len(test_cases) - 1:
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")
