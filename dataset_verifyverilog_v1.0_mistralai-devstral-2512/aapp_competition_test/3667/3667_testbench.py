import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants
WELLS_MAX = 1000
PIPES_MAX = 1000
COORD_WIDTH = 17  # 13 bits for 8192, plus sign
INDEX_WIDTH = 10  # for 1024 elements
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 100000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    min_val = -(1 << (bits-1)) if bits > 0 else 0
    max_val = (1 << bits) - 1 if bits > 0 else 0
    if v < min_val:
        return min_val
    if v > max_val:
        return max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

# Geometry helper for testing
def check_intersection(p1_start, p1_end, p2_start, p2_end, wells):
    """Check if two pipe segments intersect (not at a well)"""
    x1, y1 = p1_start
    x2, y2 = p1_end
    x3, y3 = p2_start
    x4, y4 = p2_end
    
    def cross_product(x1, y1, x2, y2, x3, y3):
        return (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1)
    
    def on_segment(x1, y1, x2, y2, x3, y3):
        if min(x1, x2) <= x3 <= max(x1, x2) and min(y1, y2) <= y3 <= max(y1, y2):
            return True
        return False
    
    d1 = cross_product(x1, y1, x2, y2, x3, y3)
    d2 = cross_product(x1, y1, x2, y2, x4, y4)
    d3 = cross_product(x3, y3, x4, y4, x1, y1)
    d4 = cross_product(x3, y3, x4, y4, x2, y2)
    
    # General case: proper intersection
    if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and \
       ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
        return True
    
    # Special cases: collinear
    if d1 == 0 and on_segment(x1, y1, x2, y2, x3, y3):
        if not is_well_point((x3, y3), wells):
            return True
    if d2 == 0 and on_segment(x1, y1, x2, y2, x4, y4):
        if not is_well_point((x4, y4), wells):
            return True
    if d3 == 0 and on_segment(x3, y3, x4, y4, x1, y1):
        if not is_well_point((x1, y1), wells):
            return True
    if d4 == 0 and on_segment(x3, y3, x4, y4, x2, y2):
        if not is_well_point((x2, y2), wells):
            return True
    
    return False

def is_well_point(point, wells):
    x, y = point
    for wx, wy in wells:
        if x == wx and y == wy:
            return True
    return False

def build_graph(pipes, wells):
    """Build adjacency list for intersection graph"""
    n = len(pipes)
    adj = [[] for _ in range(n)]
    
    for i in range(n):
        for j in range(i + 1, n):
            s1, e1x, e1y = pipes[i]
            s2, e2x, e2y = pipes[j]
            w1x, w1y = wells[s1 - 1]
            w2x, w2y = wells[s2 - 1]
            
            if check_intersection((w1x, w1y), (e1x, e1y), (w2x, w2y), (e2x, e2y), wells):
                adj[i].append(j)
                adj[j].append(i)
    
    return adj

def is_bipartite(adj):
    """Check if graph is bipartite using BFS"""
    n = len(adj)
    if n == 0:
        return True
    
    color = [-1] * n
    
    for start in range(n):
        if color[start] == -1:
            color[start] = 0
            queue = [start]
            
            while queue:
                u = queue.pop(0)
                for v in adj[u]:
                    if color[v] == -1:
                        color[v] = 1 - color[u]
                        queue.append(v)
                    elif color[v] == color[u]:
                        return False
    
    return True

def write_array(dut, name, values, width):
    """Write values to array elements"""
    for i, v in enumerate(values):
        setattr(dut, f"{name}[{i}]").value = clamp_to_width(v, width)

def write_individual_arrays(dut, wells, pipes):
    """Write individual well and pipe arrays"""
    for i, (wx, wy) in enumerate(wells):
        getattr(dut, f"well_x[{i}]").value = from_signed(clamp_to_width(wx, COORD_WIDTH), COORD_WIDTH)
        getattr(dut, f"well_y[{i}]").value = from_signed(clamp_to_width(wy, COORD_WIDTH), COORD_WIDTH)
    
    for i, (s, ex, ey) in enumerate(pipes):
        getattr(dut, f"pipe_start[{i}]").value = clamp_to_width(s, INDEX_WIDTH)
        getattr(dut, f"pipe_end_x[{i}]").value = from_signed(clamp_to_width(ex, COORD_WIDTH), COORD_WIDTH)
        getattr(dut, f"pipe_end_y[{i}]").value = from_signed(clamp_to_width(ey, COORD_WIDTH), COORD_WIDTH)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pipe_cleaning(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        if has_signal(dut, 'clk'):
            for _ in range(3):
                await RisingEdge(dut.clk)
        else:
            await Timer(30, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            'desc': 'Sample 1: 3 wells, 3 pipes - impossible',
            'wells': [(0, 0), (0, 2), (2, 0)],
            'pipes': [(1, 2, 3), (2, 2, 2), (3, 0, 3)],
            'expected': 0  # impossible
        },
        {
            'desc': 'Sample 2: 2 wells, 3 pipes - possible',
            'wells': [(0, 0), (0, 10)],
            'pipes': [(1, 5, 15), (1, 2, 15), (2, 10, 10)],
            'expected': 1  # possible
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Test: {tc['desc']}")
        
        try:
            # Write inputs
            w = len(tc['wells'])
            p = len(tc['pipes'])
            
            if has_signal(dut, 'w'):
                dut.w.value = clamp_to_width(w, INDEX_WIDTH)
            if has_signal(dut, 'p'):
                dut.p.value = clamp_to_width(p, INDEX_WIDTH)
            
            write_individual_arrays(dut, tc['wells'], tc['pipes'])
            
            # Start processing
            if has_signal(dut, 'start'):
                dut.start.value = 1
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(CLK_NS, units='ns')
                dut.start.value = 0
            else:
                await Timer(CLK_NS, units='ns')
            
            # Wait for done
            if has_signal(dut, 'done'):
                if has_signal(dut, 'clk'):
                    timeout = MAX_CYCLES
                    for _ in range(timeout):
                        await RisingEdge(dut.clk)
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            break
                    else:
                        raise TestFailure(f"Timeout after {timeout} cycles")
                else:
                    await Timer(1000, units='ns')
            else:
                await Timer(1000, units='ns')
            
            # Check result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result value undefined")
            
            result = int(dut.result.value)
            expected = tc['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}")