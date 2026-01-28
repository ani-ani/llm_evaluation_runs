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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

DATA_WIDTH = 8
MAX_N = 16
MAX_PATTERNS = 8
MAX_PAT_LEN = 16
CLK_NS = 10
MAX_CYCLES = 256

def pack_string(s, max_len=MAX_N):
    """Pack string into 16-bit value where each char is 8 bits"""
    r = 0
    for i, c in enumerate(s[:max_len]):
        r |= (ord(c) & 0xFF) << (i * 8)
    return r

def pack_patterns(patterns, max_pats=MAX_PATTERNS, max_len=MAX_PAT_LEN):
    """Pack patterns into 16x8x8-bit array (flattened)"""
    packed = [0] * (max_pats * max_len)
    for i, pat in enumerate(patterns[:max_pats]):
        for j, c in enumerate(pat[:max_len]):
            packed[i * max_len + j] = ord(c) & 0xFF
    return packed

def pack_lens(patterns, max_pats=MAX_PATTERNS):
    """Pack pattern lengths into 8x4-bit array"""
    lens = [len(p) for p in patterns[:max_pats]]
    while len(lens) < max_pats:
        lens.append(0)
    return lens

def compute_expected(street, patterns):
    """Compute expected result using Python"""
    n = len(street)
    covered = [False] * n
    for pat in patterns:
        L = len(pat)
        for start in range(n - L + 1):
            if street[start:start + L] == pat:
                for k in range(L):
                    covered[start + k] = True
    return sum(1 for c in covered if not c)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_untileable(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("abcbab", ["cb", "cbab"], 2),
        ("abab", ["bac", "baba"], 4),
        ("abcabc", ["abca", "cab"], 1),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (street, patterns, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: street='{street}', patterns={patterns}, expected={expected}")
        
        try:
            # Prepare inputs
            N = len(street)
            M = len(patterns)
            
            if N > MAX_N:
                cocotb.log.warning(f"Skipping: N={N} > MAX_N={MAX_N}")
                continue
            
            if M > MAX_PATTERNS:
                cocotb.log.warning(f"Skipping: M={M} > MAX_PATTERNS={MAX_PATTERNS}")
                continue
            
            if any(len(p) > MAX_PAT_LEN for p in patterns):
                cocotb.log.warning("Skipping: pattern too long")
                continue
            
            # Assign inputs
            if has_signal(dut, 'start'): dut.start.value = 1
            
            # Street: 16x8-bit array
            street_packed = pack_string(street)
            dut.street.value = street_packed
            
            # Pattern lengths: 8x4-bit array
            lens = pack_lens(patterns)
            for i in range(MAX_PATTERNS):
                getattr(dut, f'pattern_len_{i}').value = lens[i]
            
            # Patterns: 8x16x8-bit array (flattened)
            packed_pat = pack_patterns(patterns)
            for i in range(MAX_PATTERNS * MAX_PAT_LEN):
                getattr(dut, f'patterns_{i}').value = packed_pat[i]
            
            # M
            dut.m.value = M
            
            # Clock pulse
            if is_seq:
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                timeout = MAX_CYCLES
                for _ in range(timeout):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout after {timeout} cycles")
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")