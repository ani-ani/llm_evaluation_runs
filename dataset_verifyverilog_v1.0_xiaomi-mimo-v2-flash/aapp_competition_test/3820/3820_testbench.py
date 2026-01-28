import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

def ascii_val(char):
    return ord(char)

# Testbench Configuration
DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 200

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

async def write_string(dut, prefix, text, length):
    # Pad text to MAX_LEN with nulls
    padded = text + '\x00' * (MAX_LEN - len(text))
    for i in range(MAX_LEN):
        signal_name = f"{prefix}_char_{i}"
        if has_signal(dut, signal_name):
            val = ascii_val(padded[i])
            getattr(dut, signal_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Signal {signal_name} not found")
    
    len_name = f"{prefix}_len"
    if has_signal(dut, len_name):
        getattr(dut, len_name).value = clamp_to_width(length, 5)
    else:
        raise TestFailure(f"Signal {len_name} not found")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pattern_matching(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)

    test_cases = [
        # (s, t, expected_result, description)
        ("code*s", "codeforces", 1, "Basic wildcard"),
        ("vk*cup", "vkcup", 1, "Empty wildcard"),
        ("v", "k", 0, "No wildcard mismatch"),
        ("gfgf*gfgf", "gfgfgf", 0, "Length mismatch"),
        ("a", "a", 1, "Exact match no wildcard"),
        ("b", "a", 0, "Exact mismatch no wildcard"),
        ("*", "anything", 1, "Only wildcard"),
        ("a*", "ba", 1, "Prefix only"),
        ("a*", "ab", 1, "Prefix only 2"),
        ("*a", "ba", 1, "Suffix only"),
        ("a*b", "ab", 1, "Wildcard empty middle"),
        ("a*b", "acb", 1, "Wildcard with char"),
        ("a*b", "ac", 0, "Missing suffix"),
        ("a*b", "cb", 0, "Missing prefix"),
    ]

    passed = 0
    failed = 0

    for i, (s, t, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}/{len(test_cases)}: {desc} (S='{s}', T='{t}')")
        try:
            # Setup inputs
            await write_string(dut, 's', s, len(s))
            await write_string(dut, 't', t, len(t))

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
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")