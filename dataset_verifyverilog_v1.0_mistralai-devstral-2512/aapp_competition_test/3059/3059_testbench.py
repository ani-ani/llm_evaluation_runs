import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 2000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_speedrun(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    # Case 1: Sample 1
    n = 100
    r = 111
    m = 5
    tricks = [
        (20, 0.5, 10),
        (80, 0.5, 2),
        (85, 0.5, 2),
        (90, 0.5, 2),
        (95, 0.5, 2)
    ]
    exp = 124.0
    
    # Set inputs
    dut.m_in.value = m
    dut.n_in.value = n
    dut.r_in.value = r
    
    for i, (t, p, d) in enumerate(tricks):
        dut.t_in[i].value = t
        dut.p_in[i].value = float_to_fixed(p)
        dut.d_in[i].value = d
    
    # Trigger
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = fixed_to_float(int(dut.result.value))
    
    # Allow small error
    if abs(result - exp) > 0.001:
        raise TestFailure(f"Expected {exp}, got {result}")
    
    # Case 2: Sample 2
    await reset_dut(dut)
    n = 2
    r = 4
    m = 1
    tricks = [(1, 0.5, 5)]
    exp = 3.0
    
    dut.m_in.value = m
    dut.n_in.value = n
    dut.r_in.value = r
    dut.t_in[0].value = 1
    dut.p_in[0].value = float_to_fixed(0.5)
    dut.d_in[0].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    result = fixed_to_float(int(dut.result.value))
    if abs(result - exp) > 0.001:
        raise TestFailure(f"Expected {exp}, got {result}")
    
    # Case 3: Sample 3
    await reset_dut(dut)
    n = 10
    r = 20
    m = 3
    tricks = [
        (5, 0.3, 8),
        (6, 0.8, 3),
        (8, 0.9, 3)
    ]
    exp = 18.9029850746
    
    dut.m_in.value = m
    dut.n_in.value = n
    dut.r_in.value = r
    for i, (t, p, d) in enumerate(tricks):
        dut.t_in[i].value = t
        dut.p_in[i].value = float_to_fixed(p)
        dut.d_in[i].value = d
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    result = fixed_to_float(int(dut.result.value))
    if abs(result - exp) > 0.001:
        raise TestFailure(f"Expected {exp}, got {result}")
    
    cocotb.log.info("All tests passed")
