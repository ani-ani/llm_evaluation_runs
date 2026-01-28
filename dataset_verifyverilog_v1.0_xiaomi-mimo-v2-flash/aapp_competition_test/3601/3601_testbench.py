import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# --- Constants ---
DATA_WIDTH = 16  # Q16.16
Q_SHIFT = 65536
CLK_NS = 10
MAX_POINTS = 16
MAX_CYCLES = 2000

# --- Helpers ---
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    if v < 0: return 0
    return min((1 << bits) - 1, int(v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_fixed(f):
    return int(f * Q_SHIFT)

def fixed_to_float(v):
    if v >= 0x80000000: # Assuming 32-bit result, check MSB for sign if extended
        return (v - 0x100000000) / Q_SHIFT
    return v / Q_SHIFT

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, prefix, pts, width=16):
    for i, (x, y) in enumerate(pts):
        x_fix = float_to_fixed(x)
        y_fix = float_to_fixed(y)
        # Helper to handle flattened arrays like arr_0_x, arr_0_y
        if has_signal(dut, f'{prefix}_{i}_0'):
            getattr(dut, f'{prefix}_{i}_0').value = clamp_to_width(x_fix, width)
            getattr(dut, f'{prefix}_{i}_1').value = clamp_to_width(y_fix, width)
        # Or 2D array access if simulator supports it (cocotb handles this well usually)
        elif has_signal(dut, prefix):
            dut.__getattr__(prefix)[i][0].value = clamp_to_width(x_fix, width)
            dut.__getattr__(prefix)[i][1].value = clamp_to_width(y_fix, width)

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_delivery_optimizer(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(1, units='us')

    # --- Test Case 1 ---
    # Misha: (0,0) -> (0,10)
    # Nadia: (4,10) -> (4,0)
    # Expected: 4.0
    
    misha_pts_1 = [(0, 0), (0, 10)]
    nadia_pts_1 = [(4, 10), (4, 0)]
    
    await write_array(dut, 'misha_pts', misha_pts_1)
    await write_array(dut, 'nadia_pts', nadia_pts_1)
    
    if has_signal(dut, 'misha_len'):
        dut.misha_len.value = len(misha_pts_1)
    if has_signal(dut, 'nadia_len'):
        dut.nadia_len.value = len(nadia_pts_1)

    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    
    if has_signal(dut, 'min_time'):
        result = fixed_to_float(int(dut.min_time.value))
        expected = 4.0
        if abs(result - expected) > 0.1: # Tolerance for approximation
            raise TestFailure(f"Case 1: Expected {expected}, got {result}")

    # --- Test Case 2 ---
    # Misha: (0,0) -> (1,0)
    # Nadia: (2,0) -> (3,0) -> (3,10)
    # Expected: 5.0
    
    await reset_dut(dut)
    
    misha_pts_2 = [(0, 0), (1, 0)]
    nadia_pts_2 = [(2, 0), (3, 0), (3, 10)]
    
    await write_array(dut, 'misha_pts', misha_pts_2)
    await write_array(dut, 'nadia_pts', nadia_pts_2)
    
    if has_signal(dut, 'misha_len'):
        dut.misha_len.value = len(misha_pts_2)
    if has_signal(dut, 'nadia_len'):
        dut.nadia_len.value = len(nadia_pts_2)

    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)

    if has_signal(dut, 'min_time'):
        result = fixed_to_float(int(dut.min_time.value))
        expected = 5.0
        if abs(result - expected) > 0.1:
            raise TestFailure(f"Case 2: Expected {expected}, got {result}")

    cocotb.log.info("All tests passed")