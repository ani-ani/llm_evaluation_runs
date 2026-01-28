import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 16          # Bit width for coordinates
N = 8                    # Max number of vertices (must match Verilog parameter)
K = 8                    # Max number of points (must match Verilog parameter)
CLK_PERIOD_NS = 10
MAX_CYCLES = 20000       # Large enough for the greedy algorithm

# ============================================================================
# REFERENCE IMPLEMENTATION (Python)
# ============================================================================

def point_inside_polygon(p, poly):
    """Check if point p is strictly inside a convex polygon (CCW order)."""
    n = len(poly)
    for i in range(n):
        a = poly[i]
        b = poly[(i+1) % n]
        cross = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        if cross <= 0:  # on edge or outside
            return False
    return True

def can_remove_vertex(vertices, points, idx):
    """Check if vertex at index idx can be removed while keeping points inside."""
    new_vertices = [vertices[i] for i in range(len(vertices)) if i != idx]
    if len(new_vertices) < 3:
        return False
    for p in points:
        if not point_inside_polygon(p, new_vertices):
            return False
    return True

def greedy_min_vertices(vertices, points):
    """Return minimal number of vertices using greedy removal."""
    mask = (1 << len(vertices)) - 1  # bitmask of present vertices
    best = len(vertices)
    while True:
        changed = False
        for i in range(len(vertices)):
            if not (mask & (1 << i)):
                continue
            # Create candidate mask without i
            candidate = mask & ~(1 << i)
            # Extract vertices in order
            verts = [vertices[j] for j in range(len(vertices)) if candidate & (1 << j)]
            if len(verts) < 3:
                continue
            # Check all points
            valid = True
            for p in points:
                if not point_inside_polygon(p, verts):
                    valid = False
                    break
            if valid:
                mask = candidate
                changed = True
                best -= 1
                break  # restart scan
        if not changed:
            break
    return best

# ============================================================================
# COCOTB TEST
# ============================================================================

@cocotb.test(timeout_time=MAX_CYCLES, timeout_unit="ns")
async def test_min_vertices(dut):
    """Test the find_min_vertices module with sample inputs."""
    
    # Detect interface
    has_clk = has_signal(dut, 'clk')
    if has_clk:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases (inputs, expected_output, description)
    test_cases = [
        # Square with two points inside -> cannot remove any vertex
        (
            [(0,0), (0,3), (3,3), (3,0)],   # vertices
            [(1,1), (2,2)],                  # points
            4                                # expected min vertices
        ),
        # Octagon with points arranged such that minimal polygon is quadrilateral
        (
            [(3,0), (7,0), (10,3), (10,7), (7,10), (3,10), (0,7), (0,3)],
            [(1,3), (3,3), (5,3), (7,3), (9,3), (3,5), (5,5), (7,5), (5,7), (7,7), (7,9)],
            4
        )
    ]
    
    for case_idx, (vertices, points, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest case {case_idx+1}: {len(vertices)} vertices, {len(points)} points")
        
        # Clear inputs
        for i in range(N):
            if i < len(vertices):
                getattr(dut, f'vertex_x[{i}]').value = vertices[i][0]
                getattr(dut, f'vertex_y[{i}]').value = vertices[i][1]
            else:
                getattr(dut, f'vertex_x[{i}]').value = 0
                getattr(dut, f'vertex_y[{i}]').value = 0
        for i in range(K):
            if i < len(points):
                getattr(dut, f'point_x[{i}]').value = points[i][0]
                getattr(dut, f'point_y[{i}]').value = points[i][1]
            else:
                getattr(dut, f'point_x[{i}]').value = 0
                getattr(dut, f'point_y[{i}]').value = 0
        
        # Start computation
        if has_clk:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            # Wait for done
            cycles = 0
            while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                await RisingEdge(dut.clk)
                cycles += 1
                if cycles > MAX_CYCLES:
                    raise TestFailure("Timeout waiting for done")
            # Read result
            result = int(dut.min_vertices.value)
        else:
            # Combinational version (not used here)
            await Timer(100, units='ns')
            result = int(dut.min_vertices.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Case {case_idx+1}: expected {expected}, got {result}")
        dut._log.info(f"Case {case_idx+1} PASS: result = {result}")
    
    dut._log.info("All tests passed!")
