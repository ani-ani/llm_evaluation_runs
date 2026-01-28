import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 200

def write_array(dut, vals, width):
    for i, v in enumerate(vals):
        dut.__setattr__(f'a{i+1}').value = clamp_to_width(v, width)

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (4, [2, 3, 5, 7], 2, 3),
        (4, [2, 3, 5, 7], 3, 5),
        (4, [2, 3, 5, 7], 5, 8),
        (4, [2, 3, 5, 7], 6, 10),
        (4, [2, 3, 5, 7], 8, 13),
        (1, [10, 0, 0, 0], 1, 10),
        (1, [10, 0, 0, 0], 2, 20),
        (1, [10, 0, 0, 0], 100, 1000),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, a_vals, k_in, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, a={a_vals}, k={k_in}")
        try:
            if is_seq:
                dut.n.value = clamp_to_width(n, 4)
                dut.k_in.value = clamp_to_width(k_in, DATA_WIDTH)
                write_array(dut, a_vals, DATA_WIDTH)
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
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
