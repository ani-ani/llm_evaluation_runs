import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    min_val = -(1 << (bits - 1))
    max_val = (1 << (bits - 1)) - 1
    return min(max_val, max(min_val, v))

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    if v & (1 << 31):  # Negative in 32-bit
        return (v - (1 << 32)) / (1 << frac)
    return v / (1 << frac)

# Define test constants
DATA_WIDTH = 16
MAX_VERTICES = 10
CLK_NS = 10

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_polygon_area(dut):
    # Clock setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test Cases
    # 1. Square 0,0-2,2. Canal x=0. Polygon is fully on x>0 side? Sample says 0. 
    # Actually sample 1: Canal x=0. Polygon (0,0)-(2,0)-(2,2)-(0,2). Polygon straddles line x=0? 
    # Wait, sample 1 output is 0.0. Polygon is at x>=0. Canal is x=0. 
    # If line is x=0, the half-plane is one side. 
    # Sample 1: Square from 0 to 2. Line x=0. Intersection is line at x=0. Area 0.
    # So we need to check which side is Alob's. 
    # In problem: "Alob decided to grow corn fields on his land".
    # We need to know which side belongs to Alob. The problem implies symmetry.
    # "It is possible that the land of each person consists of several disconnected pieces"
    # "It is also possible that one person does not inherit any land at all."
    # The task is to find the largest possible area. 
    # If the polygon is split, we just need the area of the intersection with ONE half-plane.
    # The problem doesn't explicitly give which side is Alob's, but usually it's arbitrary or we assume the side containing the first point? 
    # Actually, standard interpretation: Clip polygon by the line. The result is the area. 
    # Wait, Sample 1: Square 0,0-2,2. Line 0,-1 to 0,3 (x=0). Intersection is the line x=0. Area = 0. Correct.
    # Sample 3: Polygon symmetric about y-axis. Canal is x=0 (0,0 to 1,0). 
    # Output 8.0. The polygon area is likely 16. Half is 8. Correct.
    # So the task is simply: Area(Polygon ∩ HalfPlane).
    # Which half plane? The problem says "Alob and Bice inherited... lands on one side". 
    # We don't know which side is Alob. But the problem asks for "largest possible area". 
    # Wait, "largest possible area of land to grow corn fields". 
    # If the polygon is on both sides, Alob gets one. 
    # If the problem asks for Alob's land, and we don't know which side, 
    # maybe we just calculate the area of the intersection with the line itself? No.
    # Re-reading: "Alob decided to grow corn fields... symmetrical about the canal".
    # Wait, the sample outputs match the area of the polygon clipped by the line.
    # In Sample 1, line x=0, polygon x>=0. Output 0. 
    # In Sample 3, line x=0, polygon symmetric. Output 8 (half area).
    # So we simply compute the area of the polygon on ONE side. 
    # Since the output must be deterministic, we must choose a side. 
    # Let's assume Alob's side is defined by the direction of the line vector? 
    # Or simply clip by the line and take one side.
    # Let's assume we clip using the normal vector pointing in a specific direction.
    # Actually, in geometry problems like this, usually we just clip the polygon.
    # Let's define Alob's side as the side where (x,y) satisfies the line inequality: (y-ya)*(xb-xa) - (x-xa)*(yb-ya) >= 0.
    # Or just the left side of the vector (xa,ya)->(xb,yb).
    
    # Define test case 1: Square 0,0-2,2. Line x=0.
    n = 4
    vertices = [(0,0), (2,0), (2,2), (0,2)]
    line = (0, -1, 0, 3) # x=0
    expected_area = 0.0
    
    # Input N
    if has_signal(dut, 'n'):
        dut.n.value = n
    
    # Input vertices (scaled Q16.16)
    for i in range(n):
        x_val = int(vertices[i][0] * 65536)
        y_val = int(vertices[i][1] * 65536)
        if has_signal(dut, f'arr_x_{i}'):
            getattr(dut, f'arr_x_{i}').value = clamp_to_width(x_val, 32)
            getattr(dut, f'arr_y_{i}').value = clamp_to_width(y_val, 32)
        elif has_signal(dut, 'arr_x'):
            dut.arr_x[i].value = clamp_to_width(x_val, 32)
            dut.arr_y[i].value = clamp_to_width(y_val, 32)
            
    # Input Canal
    xa, ya, xb, yb = line
    dut.xa.value = clamp_to_width(int(xa * 65536), 32)
    dut.ya.value = clamp_to_width(int(ya * 65536), 32)
    dut.xb.value = clamp_to_width(int(xb * 65536), 32)
    dut.yb.value = clamp_to_width(int(yb * 65536), 32)
    
    # Start
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    
    # Check Result
    if is_value_defined(dut.result_area.value):
        result_raw = int(dut.result_area.value)
        result_val = fixed_to_float(result_raw)
        diff = abs(result_val - expected_area)
        if diff > 0.01 and diff > expected_area * 1e-6:
            raise TestFailure(f"Test 1 failed. Expected {expected_area}, got {result_val}")
    else:
        raise TestFailure("Result signal undefined")
    
    # Test Case 2: Sample 3
    # Polygon: (-5,0), (-3,-2), (0,1), (3,-2), (5,0), (0,5)
    # Line: 0,0 to 1,0 (x-axis)
    # Area should be 8.0
    n = 6
    vertices = [(-5,0), (-3,-2), (0,1), (3,-2), (5,0), (0,5)]
    line = (0, 0, 1, 0)
    expected_area = 8.0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    if has_signal(dut, 'n'):
        dut.n.value = n
        
    for i in range(n):
        x_val = int(vertices[i][0] * 65536)
        y_val = int(vertices[i][1] * 65536)
        if has_signal(dut, f'arr_x_{i}'):
            getattr(dut, f'arr_x_{i}').value = clamp_to_width(x_val, 32)
            getattr(dut, f'arr_y_{i}').value = clamp_to_width(y_val, 32)
        elif has_signal(dut, 'arr_x'):
            dut.arr_x[i].value = clamp_to_width(x_val, 32)
            dut.arr_y[i].value = clamp_to_width(y_val, 32)
            
    xa, ya, xb, yb = line
    dut.xa.value = clamp_to_width(int(xa * 65536), 32)
    dut.ya.value = clamp_to_width(int(ya * 65536), 32)
    dut.xb.value = clamp_to_width(int(xb * 65536), 32)
    dut.yb.value = clamp_to_width(int(yb * 65536), 32)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
    if is_value_defined(dut.result_area.value):
        result_raw = int(dut.result_area.value)
        result_val = fixed_to_float(result_raw)
        diff = abs(result_val - expected_area)
        if diff > 0.01 and diff > expected_area * 1e-6:
            raise TestFailure(f"Test 2 failed. Expected {expected_area}, got {result_val}")
    else:
        raise TestFailure("Result signal undefined")