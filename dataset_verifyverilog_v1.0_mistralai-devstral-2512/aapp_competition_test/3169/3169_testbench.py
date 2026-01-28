import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 10, 8, 10, 1000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def check_intersection(x1, y1, x2, y2, x3, y3, x4, y4):
    """Check if two line segments (axis-aligned or diagonal) intersect."""
    # Simplified intersection check for integer coordinates
    # Check bounding boxes
    if max(x1, x2) < min(x3, x4) or max(x3, x4) < min(x1, x2):
        return False
    if max(y1, y2) < min(y3, y4) or max(y3, y4) < min(y1, y2):
        return False
    
    # Cross product based orientation test
    def orient(ax, ay, bx, by, cx, cy):
        return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    
    o1 = orient(x1, y1, x2, y2, x3, y3)
    o2 = orient(x1, y1, x2, y2, x4, y4)
    o3 = orient(x3, y3, x4, y4, x1, y1)
    o4 = orient(x3, y3, x4, y4, x2, y2)
    
    # General case
    if (o1 * o2 < 0) and (o3 * o4 < 0):
        return True
    
    # Special cases (collinear points)
    # We'll allow collinear overlaps as intersection for safety
    if o1 == 0 and min(x1, x2) <= x3 <= max(x1, x2) and min(y1, y2) <= y3 <= max(y1, y2):
        return True
    if o2 == 0 and min(x1, x2) <= x4 <= max(x1, x2) and min(y1, y2) <= y4 <= max(y1, y2):
        return True
    if o3 == 0 and min(x3, x4) <= x1 <= max(x3, x4) and min(y3, y4) <= y1 <= max(y3, y4):
        return True
    if o4 == 0 and min(x3, x4) <= x2 <= max(x3, x4) and min(y3, y4) <= y2 <= max(y3, y4):
        return True
    
    return False

def check_blocking(stick_i, stick_j):
    """Check if stick i blocks stick j (i's vertical translation hits j)."""
    # Stick i: (x1_i, y1_i) to (x2_i, y2_i)
    # Stick j: (x1_j, y1_j) to (x2_j, y2_j)
    # i blocks j if translating i straight down intersects j
    x1_i, y1_i, x2_i, y2_i = stick_i
    x1_j, y1_j, x2_j, y2_j = stick_j
    
    # For vertical translation, stick i moves down: its x-range stays the same
    # Its y-range becomes [0, min(y1_i, y2_i)] (moving down until y=0)
    # Actually, we need to check if ANY point of i during translation hits j
    # Simplified: if the vertical strip of i overlaps j's x-range AND
    # i's y-range (when moved down) overlaps j's y-range
    
    i_xmin = min(x1_i, x2_i)
    i_xmax = max(x1_i, x2_i)
    j_xmin = min(x1_j, x2_j)
    j_xmax = max(x1_j, x2_j)
    
    # Check x-overlap
    if i_xmax < j_xmin or j_xmax < i_xmin:
        return False
    
    # i's y-range when moving down: from 0 to max(y1_i, y2_i)
    i_ymin = 0
    i_ymax = max(y1_i, y2_i)
    j_ymin = min(y1_j, y2_j)
    j_ymax = max(y1_j, y2_j)
    
    if i_ymax < j_ymin or j_ymax < i_ymin:
        return False
    
    # If bounding boxes overlap, check actual segment intersection
    # during some translation. For simplicity, we check if the original
    # stick i, when translated to y=0, intersects j.
    # Actually, we need to check the path. Let's check if i's vertical
    # projection (the rectangle from i's x-range, y=0 to i's top) intersects j.
    # We'll check if the line segment from (i_xmin, 0) to (i_xmax, i_ymax) intersects j.
    # That's a trapezoid, complex. For our purpose, use bounding box overlap + orientation.
    # A stick blocks another if their vertical projections intersect.
    
    # Simplified: check if j's segment intersects the rectangle
    # defined by i's x-range and y-range [0, i_ymax].
    # We'll approximate with the line from (i_xmin, 0) to (i_xmax, i_ymax) and vice versa.
    # Actually, let's check if the vertical line through any point of i hits j.
    # Given the problem constraints, we'll use a simple geometric check:
    # Two segments block if their shadows on x-axis overlap AND their y-ranges overlap when i is moved down.
    # For exactness, we check intersection of j with the segment from (x1_i, 0) to (x1_i, y1_i) etc.
    
    # Let's check intersection of j with the two vertical edges of i's projection
    # and the top edge of i's projection.
    # Vertical edge 1: (i_xmin, 0) to (i_xmin, i_ymax)
    # Vertical edge 2: (i_xmax, 0) to (i_xmax, i_ymax)
    # Top edge: (i_xmin, i_ymax) to (i_xmax, i_ymax)
    
    # Check intersection with vertical edges
    if check_intersection(i_xmin, 0, i_xmin, i_ymax, x1_j, y1_j, x2_j, y2_j):
        return True
    if check_intersection(i_xmax, 0, i_xmax, i_ymax, x1_j, y1_j, x2_j, y2_j):
        return True
    # Check intersection with top edge
    if check_intersection(i_xmin, i_ymax, i_xmax, i_ymax, x1_j, y1_j, x2_j, y2_j):
        return True
    
    # Also check if j is entirely within the projection (point inside)
    # We'll consider this covered by edge intersections
    
    return False

def topological_sort(n, adj):
    """Kahn's algorithm for topological sort. Returns list of indices."""
    indeg = [0] * n
    for i in range(n):
        for j in range(n):
            if adj[i][j]:
                indeg[j] += 1
    
    queue = [i for i in range(n) if indeg[i] == 0]
    order = []
    
    while queue:
        u = queue.pop(0)
        order.append(u)
        for v in range(n):
            if adj[u][v]:
                indeg[v] -= 1
                if indeg[v] == 0:
                    queue.append(v)
    
    # If there are cycles, return None (shouldn't happen for valid input)
    if len(order) != n:
        return None
    return order

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_stick_removal(dut):
    # Initialize
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from example
    test_cases = [
        {
            'N': 4,
            'sticks': [
                [1, 3, 2, 2],  # stick 0
                [1, 1, 3, 2],  # stick 1
                [2, 4, 7, 3],  # stick 2
                [3, 3, 5, 3],  # stick 3
            ],
            'expected': [1, 3, 0, 2]  # Indices 2,4,1,3 -> 1,3,0,2
        },
        {
            'N': 4,
            'sticks': [
                [0, 0, 1, 1],  # stick 0
                [1, 2, 0, 3],  # stick 1
                [2, 2, 3, 3],  # stick 2
                [4, 0, 3, 1],  # stick 3
            ],
            'expected': [3, 2, 0, 1]  # Indices 4,3,1,2 -> 3,2,0,1
        },
        {
            'N': 3,
            'sticks': [
                [4, 6, 5, 5],  # stick 0
                [2, 1, 15, 1], # stick 1
                [3, 2, 8, 7],  # stick 2
            ],
            'expected': [1, 2, 0]  # Indices 2,3,1 -> 1,2,0
        }
    ]
    
    for test_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Running test case {test_idx + 1}")
        
        N = tc['N']
        sticks = tc['sticks']
        expected = tc['expected']
        
        # Set N
        dut.n.value = N
        
        # Set stick coordinates (only first N sticks)
        for i in range(8):
            x1, y1, x2, y2 = sticks[i] if i < N else [0, 0, 0, 0]
            getattr(dut, f'x1_{i}').value = clamp_to_width(x1, 10)
            getattr(dut, f'y1_{i}').value = clamp_to_width(y1, 10)
            getattr(dut, f'x2_{i}').value = clamp_to_width(x2, 10)
            getattr(dut, f'y2_{i}').value = clamp_to_width(y2, 10)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
        result = int(dut.result.value)
        
        # Unpack result (4 bits per index, from LSB)
        output_order = []
        for i in range(N):
            idx = (result >> (i * 4)) & 0xF
            if idx < N:
                output_order.append(idx)
        
        cocotb.log.info(f"Expected order: {expected}, Got: {output_order}")
        
        # Validate the order
        if len(output_order) != N:
            raise TestFailure(f"Output order length {len(output_order)} != N={N}")
        
        # Check if output order is valid for this test case
        # Build adjacency for validation
        adj = [[False] * N for _ in range(N)]
        for i in range(N):
            for j in range(N):
                if i != j:
                    adj[i][j] = check_blocking(sticks[i], sticks[j])
        
        # Check if output order respects dependencies
        pos = [0] * N
        for i, stick_idx in enumerate(output_order):
            pos[stick_idx] = i
        
        valid = True
        for i in range(N):
            for j in range(N):
                if adj[i][j]:  # i blocks j, so i must come before j
                    if pos[i] > pos[j]:
                        valid = False
                        cocotb.log.error(f"Invalid order: {i} blocks {j} but {i} comes after {j}")
        
        if not valid:
            raise TestFailure(f"Output order {output_order} is not valid")
        
        cocotb.log.info(f"Test case {test_idx + 1} passed")
        await RisingEdge(dut.clk)
    
    cocotb.log.info("All test cases passed!")
