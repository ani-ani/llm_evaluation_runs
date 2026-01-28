import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 32  # Fixed-point Q16.16
MAX_VAL = (1 << DATA_WIDTH) - 1
CLK_NS = 10
MAX_CYCLES = 12000

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

async def write_points(dut, N, points):
    # Assuming the module has array inputs for x, y, z
    for i in range(N):
        dut.points_x[i].value = clamp_to_width(float_to_fixed(points[i][0]), DATA_WIDTH)
        dut.points_y[i].value = clamp_to_width(float_to_fixed(points[i][1]), DATA_WIDTH)
        dut.points_z[i].value = clamp_to_width(float_to_fixed(points[i][2]), DATA_WIDTH)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_drill_diameter(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (points, expected_diameter_float)
    test_cases = [
        (
            [(1.0, 0.0, 1.4), (-1.0, 0.0, -1.4), (0.0, 1.0, -0.2)],
            2.0
        ),
        (
            [(1.4, 1.0, 0.0), (-0.4, -1.0, 0.0), (-0.1, -0.25, -0.5), (-1.2, 0.0, 0.9), (0.2, 0.5, 0.5)],
            2.0
        ),
        (
            [(435.249, -494.71, -539.356), (455.823, -507.454, -539.257), (423.394, -520.682, -538.858),
             (446.507, -501.953, -539.37), (434.266, -503.664, -560.631), (445.059, -549.71, -537.501),
             (449.65, -506.637, -513.778), (456.05, -499.715, -561.329)],
            49.9998293198
        )
    ]
    
    passed = failed = 0
    
    for i, (points, exp_dia) in enumerate(test_cases):
        N = len(points)
        cocotb.log.info(f"Test {i+1}: N={N}, expected diameter={exp_dia}")
        try:
            if is_seq:
                # Set N
                if has_signal(dut, 'N'):
                    dut.N.value = N
                # Write points
                await write_points(dut, N, points)
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.diameter.value):
                    raise TestFailure("Result undefined")
                result_fixed = int(dut.diameter.value)
                result_float = fixed_to_float(to_signed(result_fixed, DATA_WIDTH))
                
                # Compare with tolerance
                error = abs(result_float - exp_dia)
                rel_error = error / exp_dia if exp_dia != 0 else error
                if error > 1e-4 and rel_error > 1e-4:
                    raise TestFailure(f"Expected {exp_dia}, got {result_float} (error {error})")
                passed += 1
            else:
                # Combinational: assign inputs and wait
                dut.N.value = N
                await write_points(dut, N, points)
                await Timer(100, units='ns')
                if not is_value_defined(dut.diameter.value):
                    raise TestFailure("Result undefined")
                result_fixed = int(dut.diameter.value)
                result_float = fixed_to_float(to_signed(result_fixed, DATA_WIDTH))
                error = abs(result_float - exp_dia)
                if error > 1e-4:
                    raise TestFailure(f"Expected {exp_dia}, got {result_float}")
                passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")