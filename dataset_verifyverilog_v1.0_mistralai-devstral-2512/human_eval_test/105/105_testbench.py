import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
STRING_WIDTH = 64
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 500

# MANDATORY HELPERS
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

# BIT ENCODING FOR ASCII STRINGS (8-byte fixed)
string_lut = {
    1: 0x4F6E650000000000,  # "One\0\0\0\0\0"
    2: 0x54776F0000000000,  # "Two\0\0\0\0\0"
    3: 0x5468726565000000,  # "Three\0\0\0"
    4: 0x466F757200000000,  # "Four\0\0\0\0"
    5: 0x4669766500000000,  # "Five\0\0\0\0"
    6: 0x5369780000000000,  # "Six\0\0\0\0\0"
    7: 0x536576656E000000,  # "Seven\0\0\0"
    8: 0x4569676874000000,  # "Eight\0\0\0"
    9: 0x4E696E6500000000,  # "Nine\0\0\0\0"
}

def encode_string(val):
    return string_lut.get(val, 0)

def decode_string(encoded):
    # Reverse lookup for checking
    for k, v in string_lut.items():
        if v == encoded:
            return k
    return None

def get_expected_result(arr):
    # Python reference implementation
    filtered = [x for x in arr if isinstance(x, int) and 1 <= x <= 9]
    filtered.sort()  # Ascending
    filtered.reverse()  # Reverse
    return [string_lut[x] for x in filtered]

async def write_array(dut, name, vals, width):
    # Individual assignment for arrays
    for i, v in enumerate(vals):
        if i >= ARRAY_SIZE:
            break
        # Handle both packed and unpacked arrays
        try:
            getattr(dut, f'{name}[{i}]').value = clamp_to_width(v, width)
        except:
            try:
                getattr(dut, name)[i].value = clamp_to_width(v, width)
            except:
                # Try direct index
                arr_sig = getattr(dut, name)
                if hasattr(arr_sig, '__setitem__'):
                    arr_sig[i].value = clamp_to_width(v, width)

async def read_array(dut, name, width, result_len):
    results = []
    for i in range(ARRAY_SIZE):
        if i >= result_len:
            break
        try:
            val = int(getattr(dut, f'{name}[{i}]').value)
        except:
            try:
                val = int(getattr(dut, name)[i].value)
            except:
                arr_sig = getattr(dut, name)
                if hasattr(arr_sig, '__getitem__'):
                    val = int(arr_sig[i].value)
                else:
                    val = 0
        results.append(val)
    return results

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
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_by_length(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([2, 1, 1, 4, 5, 8, 2, 3], "sort filter reverse map"),
        ([], "empty array"),
        ([1, -1, 55], "filter single digit"),
        ([1, -1, 3, 2], "negative filter"),
        ([9, 4, 8], "three digits"),
        ([0, 10, 11], "no valid digits"),
        ([9,8,7,6,5,4,3,2,1], "reverse order"),
    ]
    
    passed = failed = 0
    
    for i, (inp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {inp}")
        try:
            expected = get_expected_result(inp)
            
            # Write inputs
            await write_array(dut, 'arr', inp, DATA_WIDTH)
            dut.len.value = len(inp)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(100, units='ns')
            
            # Read result
            result_len = int(dut.result_len.value) if has_signal(dut, 'result_len') else len(expected)
            actual = read_array(dut, 'result', STRING_WIDTH, result_len)
            
            # Check
            if len(actual) != len(expected):
                raise TestFailure(f"Length mismatch: expected {len(expected)}, got {len(actual)}")
            
            for j, (exp, act) in enumerate(zip(expected, actual)):
                if exp != act:
                    exp_name = next((k for k,v in string_lut.items() if v==exp), "Unknown")
                    act_name = decode_string(act) or "Unknown"
                    raise TestFailure(f"Element {j}: expected {exp_name}, got {act_name}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
