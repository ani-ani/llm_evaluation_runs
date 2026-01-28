import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers from template
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

# Array packing for string
MAX_N = 16
DATA_WIDTH = 8
PACK_WIDTH = MAX_N * DATA_WIDTH

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_string(s, max_len=MAX_N):
    val = 0
    for i, ch in enumerate(s):
        if i >= max_len: break
        val |= (ord(ch) & 0xFF) << (i * DATA_WIDTH)
    return val

def unpack_string(val, length, max_len=MAX_N):
    s = ""
    for i in range(length):
        char = (val >> (i * DATA_WIDTH)) & 0xFF
        if char != 0xFF:
            s += chr(char)
    return s

# Check function for uniqueness in Python (for testbench verification)
def check_unique(s, n):
    half = n // 2
    seen = set()
    for i in range(n - half + 1):
        sub = s[i:i+half]
        if sub in seen:
            return False
        seen.add(sub)
    return True

# Solve function for testbench reference
def solve_string(s):
    n = len(s)
    half = n // 2
    # Check if impossible: any char count > half + 1
    from collections import Counter
    cnt = Counter(s)
    if max(cnt.values()) > half + 1:
        return None
    
    candidates = [s, s[::-1], "".join(sorted(s))]
    for cand in candidates:
        if check_unique(cand, n):
            return cand
    return None

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_rearrange(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("tralalal", "allatral"),
        ("zzzz", None),
        ("annorlunda", "annorlunda")
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: Input='{input_str}', Expected='{expected}'")
        
        n = len(input_str)
        if n % 2 != 0:
            cocotb.log.info(f"Skipping odd N={n}")
            passed += 1
            continue
            
        # Load Input
        dut.str_in.value = pack_string(input_str)
        dut.N.value = n
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        await wait_for_done(dut)
        await RisingEdge(dut.clk) # Ensure stable
        
        try:
            impossible = int(dut.impossible.value)
            result_valid = int(dut.result_valid.value)
            
            if expected is None:
                if impossible == 0:
                    raise TestFailure(f"Expected impossible=1, got 0")
                if result_valid != 1:
                    raise TestFailure(f"Expected result_valid=1")
                cocotb.log.info("PASS (Correctly detected impossible)")
            else:
                if impossible == 1:
                    raise TestFailure(f"Expected impossible=0, got 1")
                if result_valid != 1:
                    raise TestFailure(f"Expected result_valid=1")
                
                out_val = int(dut.str_out.value)
                out_str = unpack_string(out_val, n)
                
                # Verify permutation
                if sorted(out_str) != sorted(input_str):
                    raise TestFailure(f"Output '{out_str}' is not a permutation of input")
                
                # Verify uniqueness
                if not check_unique(out_str, n):
                    raise TestFailure(f"Output '{out_str}' has duplicate substrings")
                
                cocotb.log.info(f"PASS (Output='{out_str}')")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
