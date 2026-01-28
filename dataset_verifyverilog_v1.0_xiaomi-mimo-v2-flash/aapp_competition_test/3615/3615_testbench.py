import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
N_MAX = 16
CLK_NS = 10
MAX_CYCLES = 256

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

def float_to_q8_8(f):
    return int(f * 256)

def q8_8_to_float(v):
    return v / 256.0

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_coords(dut, n, x_coords, y_coords):
    dut.n.value = n
    for i in range(N_MAX):
        if i < n:
            x_val = float_to_q8_8(x_coords[i])
            y_val = float_to_q8_8(y_coords[i])
            dut.x[i].value = clamp_to_width(x_val, 16)
            dut.y[i].value = clamp_to_width(y_val, 16)
        else:
            dut.x[i].value = 0
            dut.y[i].value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tower_connectivity(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, x_list, y_list, expected_result)
    test_cases = [
        (5, [1.0, 3.1, 1.0, 3.1, 4.2], [1.0, 1.0, 3.1, 3.1, 3.1], 6),
        (5, [1.0, 3.1, 1.0, 3.1, 10.0], [1.0, 1.0, 3.1, 3.1, 10.0], 5),
    ]
    
    passed = failed = 0
    
    for i, (n, xs, ys, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, expected={exp}")
        try:
            await write_coords(dut, n, xs, ys)
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
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed: raise TestFailure(f"{failed} tests failed")