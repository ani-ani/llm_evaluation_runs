import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_fixed(f, frac=16): return int(f * (1 << frac))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_point_in_convex_hull(dut):
    # Setup clock
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational
        pass

    # Test Case 1: Triangle (0,0), (10,0), (0,10) - Point (2,2) is inside
    # Coordinates scaled to Q8.8 (int * 256)
    poly = [(0,0), (10*256, 0), (0, 10*256)]
    castle = (2*256, 2*256)
    expected = 1

    # Write polygon vertices
    # Assuming interface: polygon_x[i], polygon_y[i] for i=0 to 7
    # If packed, we handle differently, but let's assume individual ports per logic ease
    # However, standard Verilog arrays are often used. Let's support `poly_x[0]` style
    
    # Writing inputs
    dut.start.value = 1
    for i in range(len(poly)):
        if has_signal(dut, f'poly_x_{i}'):
            getattr(dut, f'poly_x_{i}').value = poly[i][0]
            getattr(dut, f'poly_y_{i}').value = poly[i][1]
        elif has_signal(dut, f'poly_x'):
            # Array style
            dut.poly_x[i].value = poly[i][0]
            dut.poly_y[i].value = poly[i][1]
    
    dut.num_verts.value = len(poly)
    dut.castle_x.value = castle[0]
    dut.castle_y.value = castle[1]

    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        result = int(dut.result.value)
    else:
        # Combinational
        await Timer(100, units='ns')
        result = int(dut.result.value)

    if result != expected:
        raise TestFailure(f"Test 1 failed: Expected {expected}, got {result}")

    # Test Case 2: Same triangle, Point (15, 15) is outside
    castle = (15*256, 15*256)
    expected = 0
    
    dut.start.value = 1
    dut.castle_x.value = castle[0]
    dut.castle_y.value = castle[1]
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        result = int(dut.result.value)
    else:
        await Timer(100, units='ns')
        result = int(dut.result.value)

    if result != expected:
        raise TestFailure(f"Test 2 failed: Expected {expected}, got {result}")

    cocotb.log.info("All tests passed")