import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    if v < 0: return 0
    return min((1 << bits) - 1, v)

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Constants
MAX_N = 16
MAX_K = 8
L_MAX = 256
CLK_NS = 10
MAX_CYCLES = 4096

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    if has_signal(dut, 'inputs_valid'):
        dut.inputs_valid.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_chameleons(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test case 1 from example
    N = 2
    K = 3
    L = 10
    # Inputs: d, b, dir
    # 0 0 D -> pos=0, color=0, dir=1 (R)
    # 10 1 L -> pos=10, color=1, dir=0 (L)
    
    positions = [0, 10]
    colors = [0, 1]
    directions = [1, 0] # 1=R, 0=L

    # Populate arrays
    # dut.d, dut.b, dut.dir are expected to be unpacked arrays (e.g., d_0, d_1...)
    # or packed arrays. Assuming individual signals for robustness.
    
    dut.len.value = N
    
    for i in range(N):
        # Position Q8.8
        pos_fixed = positions[i] << 8
        if has_signal(dut, f'd_{i}'):
            getattr(dut, f'd_{i}').value = pos_fixed
        elif has_signal(dut, 'd'):
            # If it's a bus array index
            dut.d[i].value = pos_fixed
            
        # Color
        if has_signal(dut, f'b_{i}'):
            getattr(dut, f'b_{i}').value = colors[i]
        elif has_signal(dut, 'b'):
            dut.b[i].value = colors[i]
            
        # Direction
        dir_val = directions[i]
        if has_signal(dut, f'dir_{i}'):
            getattr(dut, f'dir_{i}').value = dir_val
        elif has_signal(dut, 'dir'):
            dut.dir[i].value = dir_val

    if has_signal(dut, 'inputs_valid'):
        dut.inputs_valid.value = 1
        await RisingEdge(dut.clk)
        dut.inputs_valid.value = 0
    else:
        await Timer(10, units='ns')

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await wait_for_done(dut)

    # Check outputs
    # Expected output for Sample 1:
    # 10.0 (Color 0)
    # 10.0 (Color 1)
    # 0.0 (Color 2)
    
    expected_trips = [10.0, 10.0, 0.0]

    for k in range(K):
        val = 0
        if has_signal(dut, f'total_trip_{k}'):
            val = int(getattr(dut, f'total_trip_{k}').value)
        elif has_signal(dut, 'total_trip'):
            val = int(dut.total_trip[k].value)
        
        # Convert fixed point to float for comparison
        float_val = fixed_to_float(val, 16)
        
        if abs(float_val - expected_trips[k]) > 0.01:
            raise TestFailure(f"Color {k}: Expected {expected_trips[k]}, got {float_val}")

    cocotb.log.info("Test 1 Passed")

    # --- Test Case 2 ---
    await reset_dut(dut)
    N = 4
    K = 3
    L = 7
    # 1 0 D -> 1, 0, R
    # 3 0 D -> 3, 0, R
    # 4 1 L -> 4, 1, L
    # 6 2 D -> 6, 2, R
    positions = [1, 3, 4, 6]
    colors = [0, 0, 1, 2]
    directions = [1, 1, 0, 1]
    
    dut.len.value = N
    for i in range(N):
        pos_fixed = positions[i] << 8
        if has_signal(dut, f'd_{i}'): getattr(dut, f'd_{i}').value = pos_fixed
        elif has_signal(dut, 'd'): dut.d[i].value = pos_fixed
        
        if has_signal(dut, f'b_{i}'): getattr(dut, f'b_{i}').value = colors[i]
        elif has_signal(dut, 'b'): dut.b[i].value = colors[i]
        
        if has_signal(dut, f'dir_{i}'): getattr(dut, f'dir_{i}').value = directions[i]
        elif has_signal(dut, 'dir'): dut.dir[i].value = directions[i]

    if has_signal(dut, 'inputs_valid'):
        dut.inputs_valid.value = 1
        await RisingEdge(dut.clk)
        dut.inputs_valid.value = 0

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)

    expected_trips_2 = [10.0, 4.0, 1.0]
    for k in range(K):
        val = 0
        if has_signal(dut, f'total_trip_{k}'):
            val = int(getattr(dut, f'total_trip_{k}').value)
        elif has_signal(dut, 'total_trip'):
            val = int(dut.total_trip[k].value)
        
        float_val = fixed_to_float(val, 16)
        if abs(float_val - expected_trips_2[k]) > 0.1:
            raise TestFailure(f"Color {k} (TC2): Expected {expected_trips_2[k]}, got {float_val}")

    cocotb.log.info("Test 2 Passed")