import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants based on scaled constraints
MAX_J = 16
MAX_R = 64
DATA_WIDTH = 16
COORD_WIDTH = 16
ANGLE_BINS = 32
CLK_NS = 10

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except: return False

def safe_int(v, default=0):
    try: return int(v)
    except: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper to calculate angle between two vectors
def calculate_angle(vec1, vec2):
    # vec1: (dx1, dy1), vec2: (dx2, dy2)
    dx1, dy1 = vec1
    dx2, dy2 = vec2
    dot = dx1*dx2 + dy1*dy2
    mag1 = math.sqrt(dx1*dx1 + dy1*dy1)
    mag2 = math.sqrt(dx2*dx2 + dy2*dy2)
    if mag1 == 0 or mag2 == 0: return 0.0
    cos_theta = dot / (mag1 * mag2)
    cos_theta = max(-1.0, min(1.0, cos_theta))
    angle_rad = math.acos(cos_theta)
    return math.degrees(angle_rad)

async def write_coordinates(dut, coords, coord_width=16):
    for i, (x, y) in enumerate(coords):
        if i >= MAX_J: break
        dut.coord_x_i.value = i
        dut.coord_x.value = clamp_to_width(from_signed(x, coord_width), coord_width)
        dut.coord_y.value = clamp_to_width(from_signed(y, coord_width), coord_width)
        await RisingEdge(dut.clk) # Assume sequential loading or trigger load

def pack_edges(edges, edge_width=8):
    packed = 0
    for i, (a, b) in enumerate(edges):
        if i >= 32: break # 32 edges per 32-bit word
        val = ((a & 0xF) << 4) | (b & 0xF)
        packed |= (val & ((1 << edge_width)-1)) << (i * edge_width)
    return packed

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_elisabeth_route(dut):
    # Setup clock
    clk = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clk.start())
    await reset_dut(dut)

    # Test Cases
    test_cases = [
        {
            "J": 5, "R": 6, "D": 500,
            "coords": [(-100, 0), (-100, 100), (0, 200), (100, 100), (100, 0)],
            "edges": [(1,2), (1,3), (2,3), (3,4), (3,5), (4,5)],
            "expected_angle_deg": 90.0,
            "expected_impossible": False
        },
        {
            "J": 5, "R": 6, "D": 450,
            "coords": [(-100, 0), (-100, 100), (0, 200), (100, 100), (100, 0)],
            "edges": [(1,2), (1,3), (2,3), (3,4), (3,5), (4,5)],
            "expected_angle_deg": 126.86989765,
            "expected_impossible": False
        },
        {
            "J": 5, "R": 12, "D": 440,
            "coords": [(-100, 0), (-100, 100), (0, 200), (100, 100), (100, 0)],
            "edges": [(1,2), (1,3), (3,1), (2,3), (3,2), (3,4), (4,3), (3,5), (5,3), (4,5), (5,4), (5,1)],
            "expected_angle_deg": None,
            "expected_impossible": True
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"Testing Case: J={tc['J']}, R={tc['R']}, D={tc['D']}")
        
        # Load Inputs
        dut.node_count.value = tc['J']
        dut.max_dist.value = tc['D']
        dut.src_node.value = 1
        dut.dst_node.value = tc['J']
        
        # Coordinates Loading (simplified - assume sequential or parallel loading)
        # If module has separate write ports for coords:
        for i, (x, y) in enumerate(tc['coords']):
            dut.coord_x_i.value = i + 1 # 1-indexed
            dut.coord_x.value = clamp_to_width(from_signed(x, COORD_WIDTH), COORD_WIDTH)
            dut.coord_y.value = clamp_to_width(from_signed(y, COORD_WIDTH), COORD_WIDTH)
            await RisingEdge(dut.clk)
        
        # Edges Loading
        # Assuming edge_i port exists for indexing
        for i, (a, b) in enumerate(tc['edges']):
            dut.edges_i.value = i
            dut.edges_a.value = a
            dut.edges_b.value = b
            await RisingEdge(dut.clk)

        # Start Computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check Output
        if has_signal(dut, 'impossible') and int(dut.impossible.value) == 1:
            if not tc['expected_impossible']:
                raise TestFailure(f"Unexpected Impossible result")
            cocotb.log.info("Result: Impossible (Correct)")
        else:
            if tc['expected_impossible']:
                raise TestFailure(f"Expected Impossible but got result")
            
            if not is_value_defined(dut.result_angle_deg.value):
                raise TestFailure("Result angle undefined")
            
            # Read fixed-point result
            res_bits = int(dut.result_angle_deg.value)
            # Convert Q16.16 to float
            res_float = res_bits / 65536.0
            
            # Allow tolerance
            expected = tc['expected_angle_deg']
            if abs(res_float - expected) > 1.0: # 1 degree tolerance for fixed point approx
                raise TestFailure(f"Angle mismatch. Expected {expected}, got {res_float}")
            
            cocotb.log.info(f"Result: {res_float:.2f} degrees (Correct)")
