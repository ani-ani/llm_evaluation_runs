import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

# Pack ASCII string to 128-bit packed array
def pack_string(s, max_len=16):
    if len(s) > max_len:
        s = s[:max_len]
    packed = 0
    for i, ch in enumerate(s):
        ascii_val = ord(ch)
        packed |= (ascii_val & 0xFF) << (i * 8)
    return packed

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pattern_match(dut):
    # Check if it's sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases based on Python examples
    test_cases = [
        ("ac", False, "Pattern 'ac' - no 'b' after 'a'"),
        ("dc", False, "Pattern 'dc' - no 'a' at all"),
        ("abba", True, "Pattern 'abba' - 'a' followed by 'b'"),
        ("ab", True, "Edge case 'ab'"),
        ("aa", False, "Two 'a's, no 'b'"),
        ("bb", False, "Two 'b's, no 'a'"),
        ("ba", False, "'b' before 'a'"),
        ("a", False, "Only 'a'"),
        ("b", False, "Only 'b'"),
        ("abc", True, "'a' followed by 'bc'"),
        ("xayb", True, "'a' then 'b' with chars between"),
        ("", False, "Empty string"),
    ]
    
    passed = failed = 0
    
    for i, (test_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Pack string to 128-bit
            packed = pack_string(test_str)
            dut.str_data.value = packed
            dut.str_len.value = len(test_str)
            
            # Start processing
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.match_found.value):
                    raise TestFailure("match_found is undefined")
                
                result = int(dut.match_found.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result} for '{test_str}'")
            else:
                # Combinational - wait for settling
                await Timer(100, units='ns')
                result = int(dut.match_found.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result} for '{test_str}'")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")