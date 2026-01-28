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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Fixed point helpers
def float_to_fixed(f, frac=8):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=8):
    return v / (1 << frac)

DATA_WIDTH = 8
MAX_COORD = 255
CLK_NS = 10
MAX_CYCLES = 2000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_points(dut, points):
    """Load 8 points into the module"""
    dut.points_valid.value = 0
    # Wait for ready or just assume we can write if not seq
    for i, (x, y) in enumerate(points[:8]):
        dut.points_valid.value = 1
        dut.point_idx.value = i
        dut.point_x.value = clamp_to_width(x, DATA_WIDTH)
        dut.point_y.value = clamp_to_width(y, DATA_WIDTH)
        await RisingEdge(dut.clk)
    dut.points_valid.value = 0
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_convex_area(dut):
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Simple test case from prompt
    # Input: 5 points (scaled to 0-255 range)
    # Original: (1,4), (2,2), (4,1), (3,5), (5,3)
    # Scale factor: 50 to fit 0-255
    scale = 50
    points = [
        (int(1*scale), int(4*scale)),
        (int(2*scale), int(2*scale)),
        (int(4*scale), int(1*scale)),
        (int(3*scale), int(5*scale)),
        (int(5*scale), int(3*scale))
    ]
    # Pad to 8
    while len(points) < 8:
        points.append((0,0))
    
    # Expected areas (scaled by factor^2, then fixed point)
    # Original areas: 9.0, 6.5, 2.5
    # Scaled area = area * scale^2 = area * 2500
    # Fixed point: float_to_fixed(area_scaled)
    # 9.0 * 2500 = 22500
    # 6.5 * 2500 = 16250
    # 2.5 * 2500 = 6250
    expected_raw = [22500, 16250, 6250]
    
    # Operations: L, U, R
    # Map to 2-bit codes: L=00, R=01, U=10, D=11
    ops = [0, 2, 1]
    
    if is_seq:
        # Load points
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await load_points(dut, points)
        
        # Run sequence
        for i, (op_code, exp_raw) in enumerate(zip(ops, expected_raw)):
            # Set operation for this iteration
            dut.op.value = op_code
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.area_out.value):
                raise TestFailure(f"Area output undefined on iteration {i}")
            
            result = int(dut.area_out.value)
            
            # The result is Q8.8 fixed point. 
            # The area is calculated in scaled coordinates.
            # We expect 'exp_raw' which is the integer area in scaled units.
            # The module output should be the fixed point representation of that.
            # exp_raw is already an integer (since we scaled by 2500).
            # If the module returns raw integer (shifted left 8), we compare.
            # Let's assume module computes area and keeps it in Q8.8 format.
            # Area = 0.5 * |Sum|.
            # Scaled Area = 0.5 * |Sum_scaled|.
            # We compare result with exp_raw.
            # Tolerance due to fixed point division.
            
            # Allow small error
            if abs(result - exp_raw) > 50:
                raise TestFailure(f"Iter {i}: Expected {exp_raw}, got {result}")
            
            cocotb.log.info(f"Iter {i}: Area {fixed_to_float(result, 8)} matches expected {exp_raw/2500}")
            await RisingEdge(dut.clk)
    else:
        # Combinational check (if applicable, mostly sequential here)
        # Just check if result port exists
        if not has_signal(dut, 'area_out'):
            raise TestFailure("Missing area_out signal")
        await Timer(100, units='ns')
    
    cocotb.log.info("Test passed!")