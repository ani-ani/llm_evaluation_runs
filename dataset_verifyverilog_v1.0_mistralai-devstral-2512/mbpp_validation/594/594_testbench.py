import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_expected(arr):
    first_even = None
    first_odd = None
    for val in arr:
        if first_even is None and (val & 1) == 0:
            first_even = val
        if first_odd is None and (val & 1) == 1:
            first_odd = val
        if first_even is not None and first_odd is not None:
            break
    fe = first_even if first_even is not None else 0
    fo = first_odd if first_odd is not None else 0
    return fe - fo

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_diff_even_odd(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        ([1,3,5,7,4,1,6,8], 3, "Test 1: last even first odd"),
        ([1,2,3,4,5,6,7,8,9,10], 1, "Test 2: first even=2, first odd=1"),
        ([1,5,7,9,10], 9, "Test 3: first odd=1, first even=10"),
        ([0,2,4,6,8,10,12,14], -1, "All even, no odd -> 0-0=0"),
        ([1,3,5,7,9,11,13,15], -1, "All odd, no even -> 0-0=0"),
    ]
    
    passed = failed = 0
    for i, (arr_vals, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Pad or truncate to 8 elements
            arr_vals = arr_vals[:ARRAY_SIZE]
            while len(arr_vals) < ARRAY_SIZE:
                arr_vals.append(0)
            
            # Write array
            for idx, val in enumerate(arr_vals):
                attr_name = f'arr_{idx}'
                if has_signal(dut, attr_name):
                    getattr(dut, attr_name).value = clamp_to_width(val, DATA_WIDTH)
                else:
                    raise TestFailure(f"Signal arr_{idx} not found")
            
            # Trigger
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result_val = int(dut.result.value)
            result_signed = to_signed(result_val, 16) if result_val >= 32768 else result_val
            
            expected = compute_expected(arr_vals)
            if result_signed != expected:
                raise TestFailure(f"Expected {expected}, got {result_signed}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")