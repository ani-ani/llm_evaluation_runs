import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_vertices(dut, vertices, N):
    """Write vertex coordinates to the module"""
    for i in range(16):
        if i < N:
            x, y = vertices[i]
            dut.vertices_x[i].value = clamp_to_width(float_to_fixed(x), 16)
            dut.vertices_y[i].value = clamp_to_width(float_to_fixed(y), 16)
        else:
            dut.vertices_x[i].value = 0
            dut.vertices_y[i].value = 0

async def write_points(dut, points, K):
    """Write point coordinates to the module"""
    for i in range(16):
        if i < K:
            x, y = points[i]
            dut.points_x[i].value = clamp_to_width(float_to_fixed(x), 16)
            dut.points_y[i].value = clamp_to_width(float_to_fixed(y), 16)
        else:
            dut.points_x[i].value = 0
            dut.points_y[i].value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_minimal_polygon(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (vertices, points, expected_result)
    test_cases = [
        # Case 1: Square with 2 interior points -> min vertices 4
        (
            [(0,0), (0,3), (3,3), (3,0)],
            [(1,1), (2,2)],
            4
        ),
        # Case 2: Octagon with points on central cross -> min vertices 4
        # This is a simplified version of the 8-vertex example
        (
            [(3,0), (7,0), (10,3), (10,7), (7,10), (3,10), (0,7), (0,3)],
            [(5,5), (7,7), (3,3), (7,3)],
            4
        ),
        # Case 3: Triangle with 1 point -> min vertices 3
        (
            [(0,0), (5,0), (2.5, 5)],
            [(2.5, 1)],
            3
        ),
        # Case 4: Square with 1 point at center -> min vertices 4
        (
            [(0,0), (0,4), (4,4), (4,0)],
            [(2,2)],
            4
        )
    ]
    
    for i, (vertices, points, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {i+1}: N={len(vertices)}, K={len(points)}")
        
        # Write inputs
        dut.N.value = len(vertices)
        dut.K.value = len(points)
        await write_vertices(dut, vertices, len(vertices))
        await write_points(dut, points, len(points))
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result undefined")
        
        result = int(dut.result.value)
        valid = int(dut.valid.value) if has_signal(dut, 'valid') else 1
        
        if valid == 0:
            raise TestFailure(f"Test {i+1}: Valid signal is 0")
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1} passed: Result={result}")
        
        # Reset for next test
        await reset_dut(dut)
        await Timer(100, units='ns')
    
    cocotb.log.info("All tests passed!")