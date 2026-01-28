import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools
import math

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    if val >= (1 << (bits-1)): return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0: return val + (1 << bits)
    return val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Geometry helpers for Python reference
def cross_product(a, b, c):
    # (b-a) x (c-a)
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

def convex_hull(points):
    if len(points) <= 1:
        return points
    points = sorted(set(points))
    lower = []
    for p in points:
        while len(lower) >= 2 and cross_product(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(points):
        while len(upper) >= 2 and cross_product(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]

def is_inside(point, hull):
    if len(hull) < 3:
        return False
    # Point in convex polygon check (assuming CCW order)
    for i in range(len(hull)):
        p1 = hull[i]
        p2 = hull[(i + 1) % len(hull)]
        if cross_product(p1, p2, point) <= 0:  # Strictly inside means < 0, but allow on boundary? Problem says strictly inside. <= 0 means outside or on edge.
            return False
    return True

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_onion_fence(dut):
    # Setup
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases from problem
    test_cases = [
        {
            'n_onions': 3, 'n_posts': 5, 'k': 3,
            'onions': [(1,1), (2,2), (1,3)],
            'posts': [(0,0), (0,3), (1,4), (3,3), (3,0)],
            'expected': 2
        },
        {
            'n_onions': 5, 'n_posts': 6, 'k': 4,
            'onions': [(3,5), (5,5), (4,4), (7,2), (5,2)],
            'posts': [(6,1), (4,2), (2,6), (5,6), (8,3), (8,2)],
            'expected': 4
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"Running test: N={tc['n_onions']}, M={tc['n_posts']}, K={tc['k']}")
        
        # Set constants
        dut.n_onions.value = tc['n_onions']
        dut.n_posts.value = tc['n_posts']
        dut.k_limit.value = tc['k']
        
        # Write Arrays
        # Onions
        for i in range(tc['n_onions']):
            dut.onions_x[i].value = tc['onions'][i][0]
            dut.onions_y[i].value = tc['onions'][i][1]
        # Posts
        for i in range(tc['n_posts']):
            dut.posts_x[i].value = tc['posts'][i][0]
            dut.posts_y[i].value = tc['posts'][i][1]
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        await wait_for_done(dut)
        
        # Check Result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test passed! Result: {result}")
        
        # Reset for next test
        await reset_dut(dut)
