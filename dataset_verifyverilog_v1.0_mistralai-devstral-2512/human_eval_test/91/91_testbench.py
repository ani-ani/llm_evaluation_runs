import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 128
CLK_NS = 10
MAX_CYCLES = 200

# Helper functions
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_string(s, max_len=128):
    # Packs a Python string into a 1024-bit integer
    s_bytes = s.encode('ascii')
    if len(s_bytes) > max_len:
        s_bytes = s_bytes[:max_len]
    val = 0
    for i, b in enumerate(s_bytes):
        val |= (b & 0xFF) << (i * 8)
    return val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_is_bored(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    test_cases = [
        ("Hello world", 0, "Test 1: No boredom"),
        ("Is the sky blue?", 0, "Test 2: Starts with I but not after delimiter"),
        ("I love It !", 1, "Test 3: Simple boredom"),
        ("bIt", 0, "Test 4: I in middle of word"),
        ("I feel good today. I will be productive. will kill It", 2, "Test 5: Multiple sentences"),
        ("You and I are going for a walk", 0, "Test 6: I not at start"),
        (".I", 1, "Test 7: Delimiter then I"),
        ("?I", 1, "Test 8: ? then I"),
        ("!I", 1, "Test 9: ! then I"),
        ("II", 0, "Test 10: I directly after I (no delimiter)"),
        ("", 0, "Test 11: Empty string"),
        ("I. I", 2, "Test 12: Two boredoms"),
    ]

    passed = 0
    failed = 0

    for i, (input_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i + 1}: {desc}")
        try:
            # Pack the input string into the packed array signal
            packed_val = pack_string(input_str, ARRAY_SIZE)
            dut.str_input.value = packed_val

            # Start the computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0

            # Wait for done
            await wait_for_done(dut)

            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            # Deselect start for next test
            await RisingEdge(dut.clk)

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            # Reset to ensure clean state for next test
            await reset_dut(dut)

    if failed:
        raise TestFailure(f"{failed} tests failed")
