import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 16, 10, 1000

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

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

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

async def write_triple(dut, i, a, b, c, a_width=24, b_width=24):
    getattr(dut, f'a_{i}').value = clamp_to_width(a, a_width)
    getattr(dut, f'b_{i}').value = clamp_to_width(b, b_width)
    getattr(dut, f'c_{i}').value = c

# Test case 1: Example 1
# Input: 6 lines, but we have 16 entries. We'll pad with zeros, c=0.
# S=1.0, T=1.0 (Q8.8: 0x0100)
# Expected cluster size for this fixed pair? We need to compute.
# For example, let's use a simple case where we know the answer.
# We'll compute offline for the given S/T.

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cluster_min(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test inputs: 16 entries (first 6 from example 1, rest padded)
    # a,b,c
    test_data = [
        (0, 10, 0),
        (10, 0, 1),
        (12, 8, 1),
        (5, 5, 0),
        (11, 2, 1),
        (11, 3, 0),
        (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0),
        (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0),
        (0, 0, 0), (0, 0, 0)
    ]
    
    # Set S and T (Q8.8 fixed point). Let's use S=1.0 (0x0100), T=1.0 (0x0100)
    S_val = float_to_fixed(1.0, 8)  # 0x0100
    T_val = float_to_fixed(1.0, 8)  # 0x0100
    
    if is_seq:
        dut.S.value = S_val
        dut.T.value = T_val
    
    # Write all 16 entries
    for i in range(16):
        a, b, c = test_data[i]
        await write_triple(dut, i, a, b, c)
    
    # Compute expected cluster size for this fixed pair manually
    # Weighted sum = a*1 + b*1 = a + b
    sums = [(0+10, 0), (10+0, 1), (12+8, 1), (5+5, 0), (11+2, 1), (11+3, 0)] + [(0,0)]*10
    # Sort by sum (and tie-break: c=1 before c=0)
    sorted_entries = sorted(sums, key=lambda x: (x[0], -x[1]))  # -c so c=1 comes first
    # Find cluster of c=1
    c_indices = [i for i, (sum_val, c) in enumerate(sorted_entries) if c == 1]
    if c_indices:
        first = c_indices[0]
        last = c_indices[-1]
        expected_cluster = last - first + 1
    else:
        expected_cluster = 0  # shouldn't happen per problem
    
    cocotb.log.info(f"Expected cluster size: {expected_cluster}")
    
    # Start computation
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
    result = int(dut.result.value)
    
    if result != expected_cluster:
        raise TestFailure(f"Expected {expected_cluster}, got {result}")
    
    cocotb.log.info("Test passed")
