import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_CYCLES = 1000
CLK_PERIOD_NS = 10

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# MAX FLOW COMPUTATION FOR 2x2x2 GRID
# ============================================================================
def compute_min_panels(defects):
    """
    defects: list of (x,y,z) tuples, each coordinate 0 or 1.
    Returns minimum number of panels.
    """
    # Node indices
    def cell_index(x, y, z):
        return x + 2*y + 4*z
    
    n_cells = 8
    OUTSIDE = 8
    SOURCE = 9
    SINK = 10
    n_nodes = 11
    
    # Build adjacency matrix
    cap = [[0]*n_nodes for _ in range(n_nodes)]
    
    def add_edge(u, v, c):
        cap[u][v] = c
    
    # Edges between adjacent cells and to outside
    dirs = [(1,0,0), (-1,0,0), (0,1,0), (0,-1,0), (0,0,1), (0,0,-1)]
    for x in range(2):
        for y in range(2):
            for z in range(2):
                u = cell_index(x,y,z)
                for dx,dy,dz in dirs:
                    nx, ny, nz = x+dx, y+dy, z+dz
                    if 0 <= nx < 2 and 0 <= ny < 2 and 0 <= nz < 2:
                        v = cell_index(nx,ny,nz)
                        add_edge(u, v, 1)
                    else:
                        add_edge(u, OUTSIDE, 1)
    
    # Outside to sink (infinite)
    add_edge(OUTSIDE, SINK, 1000)
    
    # Source to defects (infinite)
    for (x,y,z) in defects:
        u = cell_index(x,y,z)
        add_edge(SOURCE, u, 1000)
    
    # Edmonds-Karp
    flow = 0
    while True:
        parent = [-1] * n_nodes
        parent[SOURCE] = SOURCE
        queue = [SOURCE]
        found = False
        while queue and not found:
            u = queue.pop(0)
            for v in range(n_nodes):
                if cap[u][v] > 0 and parent[v] == -1:
                    parent[v] = u
                    if v == SINK:
                        found = True
                        break
                    queue.append(v)
        if not found:
            break
        path_flow = float('inf')
        v = SINK
        while v != SOURCE:
            u = parent[v]
            path_flow = min(path_flow, cap[u][v])
            v = u
        v = SINK
        while v != SOURCE:
            u = parent[v]
            cap[u][v] -= path_flow
            cap[v][u] += path_flow
            v = u
        flow += path_flow
    return flow

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_enclosure_solver(dut):
    """Test the enclosure_solver module."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.defect_mask.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (defects, expected_panels, description)
    test_cases = [
        ([(0,0,0)], 6, "Single cell"),
        ([(0,0,0), (0,0,1)], 10, "Two adjacent cells in z direction"),
        ([(0,0,0), (1,0,0)], 10, "Two adjacent cells in x direction"),
        ([(0,0,0), (1,1,0)], 12, "Two diagonal cells in xy plane"),
        ([(0,0,0), (1,0,0), (0,1,0)], 14, "Three cells in L shape"),
        ([(0,0,0), (1,0,0), (0,1,0), (1,1,0)], 16, "2x2 square (one layer)"),
        ([(0,0,0), (1,0,0), (0,1,0), (1,1,0), (0,0,1), (1,0,1), (0,1,1), (1,1,1)], 24, "Full 2x2x2 cube"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (defects, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        # Compute expected using Python function
        expected_result = compute_min_panels(defects)
        if expected_result != expected:
            dut._log.warning(f"Python computed {expected_result}, but expected {expected}. Using Python result.")
            expected = expected_result
        
        # Set defect inputs
        dut.defect_mask.value = 0
        for idx, (x, y, z) in enumerate(defects):
            if idx >= 8:
                raise TestFailure(f"Too many defects for test case {i}")
            # Set mask bit
            dut.defect_mask.value |= (1 << idx)
            # Set coordinates
            getattr(dut, f'x{idx}').value = x
            getattr(dut, f'y{idx}').value = y
            getattr(dut, f'z{idx}').value = z
        
        # Wait for inputs to settle
        if is_sequential:
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        
        # Start computation
        if is_sequential:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            timeout = 0
            while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                await RisingEdge(dut.clk)
                timeout += 1
                if timeout > MAX_CYCLES:
                    raise TestFailure(f"Timeout waiting for done in test {i+1}")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result undefined in test {i+1}")
            result = int(dut.result.value)
        else:
            # Combinational module
            await Timer(100, units='ns')
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result undefined in test {i+1}")
            result = int(dut.result.value)
        
        # Verify
        if result != expected:
            dut._log.error(f"Test {i+1} FAILED: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {i+1} PASSED: result = {result}")
            passed += 1
        
        # Clear inputs for next test
        dut.defect_mask.value = 0
        if is_sequential:
            await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
