import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 16
MAX_N = 16
CLK_NS = 10
MAX_CYCLES = 100000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: v = 0
    if v > max_val: v = max_val
    return v

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_point(coords, bits_per_coord=16):
    """Pack array of coordinates into single integer."""
    result = 0
    for i, val in enumerate(coords):
        result |= (val & ((1 << bits_per_coord) - 1)) << (i * bits_per_coord)
    return result

def manhattan_dist(p1, p2):
    return abs(p1[0] - p2[0]) + abs(p1[1] - p2[1])

def compute_expected(points):
    """Compute expected result for Python reference."""
    n = len(points)
    if n == 0:
        return 0
    
    # Pre-compute all distances
    dist = [[0]*n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            dist[i][j] = manhattan_dist(points[i], points[j])
    
    if n <= 2:
        return 0
    
    min_max_diameter = 0xFFFF
    
    # Iterate all non-trivial partitions (mask from 1 to 2^n-2)
    for mask in range(1, (1 << n) - 1):
        set_a = []
        set_b = []
        for i in range(n):
            if mask & (1 << i):
                set_a.append(i)
            else:
                set_b.append(i)
        
        if len(set_a) == 0 or len(set_b) == 0:
            continue
        
        # Compute diameter for each set
        diam_a = 0
        if len(set_a) > 1:
            for i in range(len(set_a)):
                for j in range(i+1, len(set_a)):
                    d = dist[set_a[i]][set_a[j]]
                    if d > diam_a:
                        diam_a = d
        
        diam_b = 0
        if len(set_b) > 1:
            for i in range(len(set_b)):
                for j in range(i+1, len(set_b)):
                    d = dist[set_b[i]][set_b[j]]
                    if d > diam_b:
                        diam_b = d
        
        max_diam = max(diam_a, diam_b)
        if max_diam < min_max_diameter:
            min_max_diameter = max_diam
    
    return min_max_diameter

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bicycle_couriers(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        {
            'points': [(1,1), (4,1), (1,5), (10,10), (10,8), (7,10)],
            'expected': 7,
            'desc': 'Example 1: 6 points'
        },
        {
            'points': [(0,0), (100,100), (0,100), (100,0), (50,50), (0,50), (100,50)],
            'expected': 100,
            'desc': 'Example 2: 7 points'
        },
        {
            'points': [(0,0), (10,0), (0,10), (10,10)],
            'expected': 10,
            'desc': 'Square corners'
        },
        {
            'points': [(0,0), (1,0)],
            'expected': 0,
            'desc': 'Two points only'
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test_case in enumerate(test_cases):
        points = test_case['points']
        expected = test_case['expected']
        desc = test_case['desc']
        n = len(points)
        
        if n > MAX_N:
            cocotb.log.info(f"Skipping {desc}: N={n} > MAX_N={MAX_N}")
            continue
        
        cocotb.log.info(f"Test {test_idx+1}: {desc} (N={n})")
        
        try:
            # Pack coordinates into 16-bit vectors
            x_coords = [p[0] for p in points]
            y_coords = [p[1] for p in points]
            
            packed_x = pack_point(x_coords, 16)
            packed_y = pack_point(y_coords, 16)
            
            # Set inputs
            if has_signal(dut, 'N'):
                dut.N.value = n
            if has_signal(dut, 'point_x'):
                dut.point_x.value = clamp_to_width(packed_x, 16)
            if has_signal(dut, 'point_y'):
                dut.point_y.value = clamp_to_width(packed_y, 16)
            
            # Start computation
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    
                    # Wait for done
                    for cycle in range(MAX_CYCLES):
                        await RisingEdge(dut.clk)
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            break
                        if cycle == MAX_CYCLES - 1:
                            raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                else:
                    # No start signal, just wait
                    await Timer(100, units='ns')
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")
