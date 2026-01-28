import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools
import random

# Helpers
DATA_WIDTH = 32
MAX_VAL = (1 << DATA_WIDTH) - 1
CLK_NS = 10
MAX_CYCLES = 10000

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
    # Handle signed
    if v < 0:
        v = v + (1 << bits)
    return min((1 << bits) - 1, max(0, v))

def to_signed_32bit(val):
    """Convert to 32-bit signed representation"""
    return clamp_to_width(val, 32)

def from_signed_32bit(val):
    """Convert from 32-bit signed to Python int"""
    if val >= (1 << 31):
        return val - (1 << 32)
    return val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Cube geometry helpers
def dist2(p1, p2):
    return sum([(p1[i]-p2[i])**2 for i in range(3)])

def is_valid_cube(vertices):
    """Check if 8 vertices form a cube"""
    if len(vertices) != 8:
        return False
    
    # Compute all pairwise squared distances
    dists = []
    for i in range(8):
        for j in range(i+1, 8):
            d = dist2(vertices[i], vertices[j])
            dists.append(d)
    
    if 0 in dists:
        return False
    
    dists.sort()
    # For a cube: expect 12 edges, 12 face diagonals, 4 space diagonals
    # So distance multiset should be: 12×S, 12×2S, 4×3S
    unique_dists = list(set(dists))
    if len(unique_dists) != 3:
        return False
    
    s = unique_dists[0]
    if dists.count(s) != 12:
        return False
    if dists.count(2*s) != 12:
        return False
    if dists.count(3*s) != 4:
        return False
    
    return True

def generate_test_case(valid=True):
    """Generate a test case with 8 vertices"""
    if valid:
        # Create a simple unit cube
        vertices = []
        for i in range(8):
            v = [
                (i >> 0) & 1,
                (i >> 1) & 1,
                (i >> 2) & 1
            ]
            vertices.append(v)
        # Permute coordinates for each vertex (simulate Nick's operations)
        input_verts = []
        for v in vertices:
            perm = list(range(3))
            random.shuffle(perm)
            pv = [v[perm[j]] for j in range(3)]
            input_verts.append(pv)
        return input_verts, True
    else:
        # Invalid case: all same points
        return [[0, 0, 0] for _ in range(8)], False

@cocotb.test(timeout_time=20000, timeout_unit="ms")
async def test_cube_reconstruction(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        # Simple valid case
        ([
            [0,0,0], [0,0,1], [0,1,0], [0,1,1],
            [1,0,0], [1,0,1], [1,1,0], [1,1,1]
        ], True, "Unit cube axis-aligned"),
        # Invalid case
        ([
            [0,0,0], [0,0,0], [0,0,0], [0,0,0],
            [1,1,1], [1,1,1], [1,1,1], [1,1,1]
        ], False, "Invalid duplicate points"),
        # Valid but permuted (like first example)
        ([
            [0,0,0],
            [0,0,1],
            [0,0,1],  # Note: these are permuted versions
            [0,0,1],
            [0,1,1],
            [0,1,1],
            [0,1,1],
            [1,1,1]
        ], True, "Permuted cube vertices"),
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, (input_verts, expected_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {tc_idx+1}: {desc}")
        try:
            # Write input to DUT
            for vert_idx in range(8):
                for coord_idx in range(3):
                    signal_name = f'coords_{vert_idx}_{coord_idx}'
                    if has_signal(dut, signal_name):
                        val = input_verts[vert_idx][coord_idx]
                        getattr(dut, signal_name).value = to_signed_32bit(val)
                    else:
                        raise TestFailure(f"Signal {signal_name} not found")
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            # Check result
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal undefined")
            
            result_valid = int(dut.valid.value) == 1
            
            if result_valid:
                # Read output vertices
                output_verts = []
                for vert_idx in range(8):
                    v = []
                    for coord_idx in range(3):
                        signal_name = f'out_coords_{vert_idx}_{coord_idx}'
                        if has_signal(dut, signal_name):
                            val = getattr(dut, signal_name).value
                            v.append(from_signed_32bit(int(val)))
                        else:
                            raise TestFailure(f"Output signal {signal_name} not found")
                    output_verts.append(v)
                
                # Validate cube geometry
                if not is_valid_cube(output_verts):
                    raise TestFailure(f"Output geometry invalid: {output_verts}")
                
                # Verify output matches input multiset
                input_sorted = sorted([sorted(v) for v in input_verts])
                output_sorted = sorted([sorted(v) for v in output_verts])
                if input_sorted != output_sorted:
                    raise TestFailure("Output vertices don't match input multiset")
                
                cocotb.log.info(f"  PASS: Valid cube found")
            else:
                if expected_valid:
                    raise TestFailure(f"Expected valid cube but got invalid")
                cocotb.log.info(f"  PASS: Correctly rejected invalid input")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All tests passed: {passed}/{passed + failed}")