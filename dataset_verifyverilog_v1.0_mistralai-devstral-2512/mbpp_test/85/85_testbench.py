import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

Q16_16 = 65536
FIXED_PI = 0x3243F  # 3.141592653589793 * 65536

def float_to_fixed(f):
    return int(f * Q16_16)

def fixed_to_float(v):
    return v / Q16_16

async def wait_for_done(dut, max_cycles=1000):
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

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_sphere_area(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (10, 1256.6370614359173),
        (15, 2827.4333882308138),
        (20, 5026.548245743669)
    ]
    
    for r_input, expected in test_cases:
        dut.rst_n.value = 1
        dut.start.value = 1
        dut.radius.value = clamp_to_width(r_input, 8)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut, max_cycles=50)
        
        result_val = int(dut.result.value)
        result_float = fixed_to_float(result_val)
        
        rel_error = abs(result_float - expected) / max(1e-6, abs(expected))
        
        if rel_error > 0.001:
            raise TestFailure(f"Radius {r_input}: Expected {expected:.6f}, got {result_float:.6f} (err={rel_error:.6f})")
        
        cocotb.log.info(f"Radius {r_input}: {result_float:.6f} ≈ {expected:.6f} ✓")
        await RisingEdge(dut.clk)
