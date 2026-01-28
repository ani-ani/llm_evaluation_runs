import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Specific helpers for this testbench
def str_to_ascii(s):
    return [ord(c) for c in s]

async def write_string(dut, s):
    ascii_vals = str_to_ascii(s)
    for i in range(ARRAY_SIZE):
        val = ascii_vals[i] if i < len(ascii_vals) else 0
        getattr(dut, f'char_{i}').value = clamp_to_width(val, DATA_WIDTH)
    dut.len.value = clamp_to_width(len(ascii_vals), 4)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Main Test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_count_upper(dut):
    # Setup clock and reset
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational (implied, but code structure assumes sequential for simplicity)
        await Timer(10, units='ns')

    # Test cases: (input_string, expected_count, description)
    test_cases = [
        ('aBCdEf', 1, "mixed case even uppercase vowel"),
        ('abcdefg', 0, "lowercase only"),
        ('dBBE', 0, "uppercase consonants at even"),
        ('B', 0, "single consonant"),
        ('U', 1, "single uppercase vowel"),
        ('', 0, "empty string"),
        ('EEEE', 2, "all uppercase vowels at even indices"),
    ]

    passed = 0
    failed = 0

    for i, (inp_str, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input data
            if is_seq:
                await write_string(dut, inp_str)
            else:
                await write_string(dut, inp_str) # Even combinational needs data setup

            # Trigger computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational assumption: result available after small delay
                await Timer(50, units='ns')

            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")