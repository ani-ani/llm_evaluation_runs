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

DATA_WIDTH = 16
RESULT_WIDTH = 20
CLK_NS = 10
MAX_CYCLES = 2000
MODULO = 1000003

def compute_expected(points):
    n = len(points)
    total = 0
    from itertools import combinations
    for combo in combinations(range(n), 4):
        pts = [points[i] for i in combo]
        # Order points by angle around centroid to ensure convex quadrilateral
        cx = sum(p[0] for p in pts)/4
        cy = sum(p[1] for p in pts)/4
        pts.sort(key=lambda p: (p[0]-cx, p[1]-cy))  # simple sort, assume convex
        x = [p[0] for p in pts]
        y = [p[1] for p in pts]
        area2 = 0
        for i in range(4):
            j = (i+1) % 4
            area2 += x[i]*y[j] - x[j]*y[i]
        area2 = abs(area2)
        total = (total + area2) % MODULO
    return total

async def write_points(dut, points):
    for i, (x_val, y_val) in enumerate(points):
        dut.x[i].value = clamp_to_width(from_signed(x_val, DATA_WIDTH), DATA_WIDTH)
        dut.y[i].value = clamp_to_width(from_signed(y_val, DATA_WIDTH), DATA_WIDTH)
    dut.n.value = len(points)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_quadrilaterals(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test case 1: 4 points forming a diamond
    points1 = [(2,0), (0,2), (-2,0), (0,-2)]
    exp1 = compute_expected(points1)
    
    # Test case 2: 5 points
    points2 = [(2,0), (0,2), (-2,0), (0,-2), (2,2)]
    exp2 = compute_expected(points2)
    
    test_cases = [(points1, exp1, "4 points diamond"), (points2, exp2, "5 points")]
    passed = failed = 0
    
    for i, (points, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await write_points(dut, points)
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                if not done:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")