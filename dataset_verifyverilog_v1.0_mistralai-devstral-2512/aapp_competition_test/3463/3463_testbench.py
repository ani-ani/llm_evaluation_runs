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

def float_to_fixed(f, frac=8):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=8):
    return v / (1 << frac)

def write_probabilities(dut, probs, width=8):
    for i, p in enumerate(probs):
        val = float_to_fixed(p, 8)
        val = clamp_to_width(val, width)
        getattr(dut, f'p_{i}').value = val

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_anthony_probability(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: N=1, M=1, p=0.5
    dut.N.value = 1
    dut.M.value = 1
    write_probabilities(dut, [0.5], 8)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    result = int(dut.result.value)
    expected = float_to_fixed(0.5, 8)
    if result != expected:
        raise TestFailure(f"Test 1 failed: expected {expected}, got {result}")
    cocotb.log.info(f"Test 1 passed: result={result}, expected={expected}")
    
    # Test case 2: N=3, M=2, p=[1.0, 0.0, 1.0, 0.0]
    await reset_dut(dut)
    dut.N.value = 3
    dut.M.value = 2
    write_probabilities(dut, [1.0, 0.0, 1.0, 0.0], 8)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    result = int(dut.result.value)
    expected = float_to_fixed(1.0, 8)
    if result != expected:
        raise TestFailure(f"Test 2 failed: expected {expected}, got {result}")
    cocotb.log.info(f"Test 2 passed: result={result}, expected={expected}")
    
    # Test case 3: N=3, M=2, p=[0.0, 0.0, 0.0, 0.0]
    await reset_dut(dut)
    dut.N.value = 3
    dut.M.value = 2
    write_probabilities(dut, [0.0, 0.0, 0.0, 0.0], 8)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    result = int(dut.result.value)
    expected = float_to_fixed(0.0, 8)
    if result != expected:
        raise TestFailure(f"Test 3 failed: expected {expected}, got {result}")
    cocotb.log.info(f"Test 3 passed: result={result}, expected={expected}")