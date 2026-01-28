import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 200

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

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return max(0, min(max_val, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def str_to_ascii_array(s):
    # Returns list of ints (0-255)
    return [ord(c) for c in s]

def ascii_array_to_str(vals):
    # Converts list of ints back to string, ignoring zeros
    return ''.join(chr(v) for v in vals if v != 0)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string_input(dut, s):
    # Clear array
    for i in range(ARRAY_SIZE):
        getattr(dut, f'str_in_{i}').value = 0
    
    # Write valid chars
    arr = str_to_ascii_array(s)
    for i, val in enumerate(arr):
        if i >= ARRAY_SIZE:
            break
        getattr(dut, f'str_in_{i}').value = clamp_to_width(val, DATA_WIDTH)
    
    dut.len_in.value = clamp_to_width(len(arr), 4)

async def read_string_output(dut):
    # Read array
    vals = []
    for i in range(ARRAY_SIZE):
        v = safe_int(getattr(dut, f'str_out_{i}').value)
        vals.append(v)
    
    # Convert to string
    return ascii_array_to_str(vals), safe_int(dut.len_out.value)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_snake_to_camel(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must be sequential (have 'clk' signal)")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    test_cases = [
        ("android_tv", "AndroidTv", "simple snake"),
        ("google_pixel", "GooglePixel", "two words"),
        ("apple_watch", "AppleWatch", "short string"),
        ("a_b_c", "ABC", "single letters"),
        ("test", "Test", "no underscore"),
        ("multiple_words_here", "MultipleWordsHere", "longer string"),
        ("_leading", "Leading", "leading underscore"),
        ("trailing_", "Trailing", "trailing underscore"),
        ("double__underscore", "DoubleUnderscore", "double underscore"),
        ("a", "A", "single char"),
        ("", "", "empty string")
    ]

    passed = 0
    failed = 0

    for inp, exp_out, desc in test_cases:
        cocotb.log.info(f"Test: {desc} | In: '{inp}' | Exp: '{exp_out}'")
        try:
            await write_string_input(dut, inp)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            result_str, res_len = await read_string_output(dut)
            
            if result_str != exp_out:
                raise TestFailure(f"Expected '{exp_out}', got '{result_str}' (len {res_len})")
            
            passed += 1
            cocotb.log.info(f"  PASS: Got '{result_str}'")

        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
