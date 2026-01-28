import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

# Testbench constants
CLK_NS = 10
MAX_CYCLES = 2000  # For n=8, MST takes ~100 cycles
DATA_WIDTH = 32

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

async def write_sx(dut, idx, x, s):
    # Assuming ports s_x_i, s_s_i or packed
    if has_signal(dut, f's_x_{idx}'):
        dut.__getattr__(f's_x_{idx}').value = x
        dut.__getattr__(f's_s_{idx}').value = clamp_to_width(s, DATA_WIDTH)
    else:
        # Fallback to packed if needed, but spec uses arrays
        dut.s_x[idx].value = x
        dut.s_s[idx].value = clamp_to_width(s, DATA_WIDTH)

async def write_a(dut, n, a_vals):
    # a_vals is flat list of n*(n+1) values
    # Ports: a_flat_0 to a_flat_n*(n+1)-1
    if has_signal(dut, 'a_flat_0'):
        for i, v in enumerate(a_vals):
            dut.__getattr__(f'a_flat_{i}').value = clamp_to_width(v, DATA_WIDTH)
    else:
        # Assuming unpacked a[i][j] ports
        for i in range(n):
            for j in range(n+1):
                dut.__getattr__(f'a_{i}_{j}').value = clamp_to_width(a_vals[i*(n+1)+j], DATA_WIDTH)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_prince(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: n=3, from example
    n = 3
    s_x = [1, 3, 2]
    s_s = [1, 1, 1]
    # a[i][j] flattened row-major: i from 0 to 2, j from 0 to 3
    a_flat = [
        40, 30, 20, 10,
        95, 95, 95, 10,
        95, 50, 30, 20
    ]
    expected = 91
    
    if is_seq:
        dut.n.value = n
        for i in range(n):
            await write_sx(dut, i, s_x[i], s_s[i])
        await write_a(dut, n, a_flat)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        else:
            cocotb.log.info(f"Test passed: result {result}")
    else:
        # Combinational: just wait
        dut.n.value = n
        for i in range(n):
            await write_sx(dut, i, s_x[i], s_s[i])
        await write_a(dut, n, a_flat)
        await Timer(100, units='ns')
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")

    # Test case 2: n=4, all same
    n = 4
    s_x = [4, 4, 4, 4]
    s_s = [4, 4, 4, 4]
    a_flat = [
        5, 5, 5, 5, 5,
        5, 5, 5, 5, 5,
        5, 5, 5, 5, 5,
        5, 5, 5, 5, 5
    ]
    expected = 17
    
    if is_seq:
        dut.n.value = n
        for i in range(n):
            await write_sx(dut, i, s_x[i], s_s[i])
        await write_a(dut, n, a_flat)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        else:
            cocotb.log.info(f"Test passed: result {result}")
    else:
        dut.n.value = n
        for i in range(n):
            await write_sx(dut, i, s_x[i], s_s[i])
        await write_a(dut, n, a_flat)
        await Timer(100, units='ns')
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")