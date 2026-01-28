import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 32
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

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

def string_to_array(s, max_len=32):
    # Convert string to ASCII array, pad with spaces
    arr = [ord(c) for c in s]
    arr += [32] * (max_len - len(arr))  # pad with space
    return arr[:max_len]

async def write_string(dut, s):
    arr = string_to_array(s, ARRAY_SIZE)
    if hasattr(dut, 'str'):
        for i, v in enumerate(arr):
            dut.str[i].value = clamp_to_width(v, DATA_WIDTH)
    elif hasattr(dut, 'str_0'):
        for i in range(ARRAY_SIZE):
            getattr(dut, f'str_{i}').value = arr[i]
    else:
        # Try packed array
        packed = 0
        for i, v in enumerate(arr):
            packed |= (v & ((1 << DATA_WIDTH)-1)) << (i * DATA_WIDTH)
        dut.str.value = packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
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

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_fruit_distribution(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("5 apples and 6 oranges", 19, 8),
        ("5 apples and 6 oranges", 21, 10),
        ("0 apples and 1 oranges", 3, 2),
        ("1 apples and 0 oranges", 3, 2),
        ("2 apples and 3 oranges", 100, 95),
        ("2 apples and 3 oranges", 5, 0),
        ("1 apples and 100 oranges", 120, 19),
        ("10 apples and 10 oranges", 255, 235),  # Edge case max
        ("0 apples and 0 oranges", 10, 10),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s, total, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{s}' total={total}")
        try:
            # Write inputs
            await write_string(dut, s)
            dut.total.value = clamp_to_width(total, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.mango.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.mango.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
