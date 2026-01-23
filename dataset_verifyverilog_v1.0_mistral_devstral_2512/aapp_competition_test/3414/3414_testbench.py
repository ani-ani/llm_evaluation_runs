import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
NODE_COUNT = 8
COORD_WIDTH = 16
FIXED_POINT_WIDTH = 32
FIXED_POINT_FRACTION = 16
DATA_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def float_to_fixed(f, frac_bits=FIXED_POINT_FRACTION):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FIXED_POINT_FRACTION):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

def pack_matrix(matrix, rows, cols):
    """Pack 2D boolean matrix into array of integers for Verilog."""
    packed = []
    for row in range(rows):
        val = 0
        for col in range(cols):
            if matrix[row][col]:
                val |= (1 << col)
        packed.append(val)
    return packed

def calculate_turning_angle(x1, y1, x2, y2, x3, y3):
    """Calculate turning angle at node (x2,y2) from edge (1->2) to (2->3)."""
    # Vector from node to first neighbor (incoming direction reversed)
    dx1 = x2 - x1
    dy1 = y2 - y1
    # Vector from node to second neighbor (outgoing direction)
    dx2 = x3 - x2
    dy2 = y3 - y2
    
    # Calculate angles using atan2
    angle1 = math.atan2(dy1, dx1)
    angle2 = math.atan2(dy2, dx2)
    
    # Difference
    diff = abs(angle2 - angle1)
    if diff > math.pi:
        diff = 2 * math.pi - diff
    
    # The turning angle is the supplement to make straight line = 0
    return math.pi - diff

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_eulerian_turning_minimizer(dut):
    """Test the Eulerian Turning Minimizer module."""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test Case 1: Simple triangle (3 nodes, 3 edges)
    # Nodes: (0,0), (0,1), (1,0)
    # Edges: 0-1, 0-2, 1-2
    # Expected: 2*pi radians (approximately 6.283185)
    
    cocotb.log.info("Test Case 1: Triangle (3 nodes)")
    
    # Set up nodes
    nodes_x = [0, 0, 1]
    nodes_y = [0, 1, 0]
    
    for i in range(3):
        if has_signal(dut, f'node_x_{i}'):
            getattr(dut, f'node_x_{i}').value = nodes_x[i]
            getattr(dut, f'node_y_{i}').value = nodes_y[i]
        else:
            dut.node_x[i].value = nodes_x[i]
            dut.node_y[i].value = nodes_y[i]
    
    # Set up adjacency matrix
    adj_matrix = [
        [0, 1, 1],  # Node 0 connected to 1,2
        [1, 0, 1],  # Node 1 connected to 0,2
        [1, 1, 0]   # Node 2 connected to 0,1
    ]
    
    packed_adj = pack_matrix(adj_matrix, NODE_COUNT, NODE_COUNT)
    for i in range(NODE_COUNT):
        if has_signal(dut, f'adj_matrix_{i}'):
            getattr(dut, f'adj_matrix_{i}').value = packed_adj[i]
        else:
            dut.adj_matrix[i].value = packed_adj[i]
    
    # Set configuration
    dut.actual_node_count.value = 3
    dut.actual_edge_count.value = 3
    
    if is_sequential:
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_wait = 500
        for _ in range(max_wait):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done signal")
    else:
        # Combinational - wait for propagation
        await Timer(100, units='ns')
    
    # Read result
    if not is_value_defined(dut.total_turning.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result_fixed = int(dut.total_turning.value)
    result_float = fixed_to_float(result_fixed)
    
    expected = 2 * math.pi  # 6.28318530718
    error = abs(result_float - expected)
    
    cocotb.log.info(f"Result: {result_float:.6f} radians")
    cocotb.log.info(f"Expected: {expected:.6f} radians")
    cocotb.log.info(f"Error: {error:.9f}")
    
    if error > 1e-4:  # Allow small error for fixed-point
        raise TestFailure(f"Test 1 failed: error {error:.9f} > 1e-4")
    
    cocotb.log.info("Test Case 1: PASS")
    
    # Test Case 2: More complex graph (adapted from example 2)
    # We'll use a smaller version with 4 nodes to keep it feasible
    cocotb.log.info("Test Case 2: Diamond graph (4 nodes)")
    
    # Reset for next test
    if is_sequential:
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Nodes for diamond: (0,0), (1,0), (0.5,1), (0.5,-1)
    nodes_x = [0, 2, 1, 1]
    nodes_y = [0, 0, 2, -2]
    
    for i in range(4):
        if has_signal(dut, f'node_x_{i}'):
            getattr(dut, f'node_x_{i}').value = nodes_x[i]
            getattr(dut, f'node_y_{i}').value = nodes_y[i]
        else:
            dut.node_x[i].value = nodes_x[i]
            dut.node_y[i].value = nodes_y[i]
    
    # Diamond: 0-1, 0-2, 1-3, 2-3 (Eulerian circuit exists)
    adj_matrix = [
        [0, 1, 1, 0],  # Node 0
        [1, 0, 0, 1],  # Node 1
        [1, 0, 0, 1],  # Node 2
        [0, 1, 1, 0]   # Node 3
    ]
    
    packed_adj = pack_matrix(adj_matrix, NODE_COUNT, NODE_COUNT)
    for i in range(NODE_COUNT):
        if has_signal(dut, f'adj_matrix_{i}'):
            getattr(dut, f'adj_matrix_{i}').value = packed_adj[i]
        else:
            dut.adj_matrix[i].value = packed_adj[i]
    
    dut.actual_node_count.value = 4
    dut.actual_edge_count.value = 4
    
    if is_sequential:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        max_wait = 500
        for _ in range(max_wait):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done signal")
    else:
        await Timer(100, units='ns')
    
    result_fixed = int(dut.total_turning.value)
    result_float = fixed_to_float(result_fixed)
    
    # Expected turning for diamond: depends on path but should be minimal
    # We'll just check it's within reasonable bounds
    cocotb.log.info(f"Result: {result_float:.6f} radians")
    
    if result_float < 0 or result_float > 4 * math.pi:
        raise TestFailure(f"Result {result_float} out of expected range")
    
    cocotb.log.info("Test Case 2: PASS")
    
    cocotb.log.info("="*50)
    cocotb.log.info("All tests passed successfully!")
