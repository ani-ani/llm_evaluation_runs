import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16  # Coordinates are 16-bit Q8.8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# Helper functions
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Fixed-point conversion
SCALE = 256  # 2^8 for Q8.8

def float_to_fixed(f):
    return int(f * SCALE)

# Compute expected result using the simplified two-component algorithm
def compute_expected(towers):
    n = len(towers)
    if n == 0:
        return 1
    # Compute pairwise distances and build components
    parent = list(range(n))
    size = [1] * n
    
    def find(x):
        while parent[x] != x:
            x = parent[x]
        return x
    
    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            if size[ra] < size[rb]:
                parent[ra] = rb
                size[rb] += size[ra]
            else:
                parent[rb] = ra
                size[ra] += size[rb]
    
    # Build graph
    for i in range(n):
        for j in range(i+1, n):
            x1, y1 = towers[i]
            x2, y2 = towers[j]
            dx = x1 - x2
            dy = y1 - y2
            dist_sq = dx*dx + dy*dy
            if dist_sq <= 4 * SCALE * SCALE:  # 4 km squared, scaled
                union(i, j)
    
    # Find components
    comp_map = {}
    for i in range(n):
        root = find(i)
        if root not in comp_map:
            comp_map[root] = []
        comp_map[root].append(i)
    
    components = list(comp_map.values())
    comp_sizes = [len(c) for c in components]
    
    # Maximum from single component
    max_towers = max(comp_sizes) + 1
    
    # Check pairs of components
    for i in range(len(components)):
        for j in range(i+1, len(components)):
            # Check if any pair of towers from the two components are within 4 km
            min_dist = float('inf')
            for idx_i in components[i]:
                for idx_j in components[j]:
                    x1, y1 = towers[idx_i]
                    x2, y2 = towers[idx_j]
                    dx = x1 - x2
                    dy = y1 - y2
                    dist_sq = dx*dx + dy*dy
                    if dist_sq < min_dist:
                        min_dist = dist_sq
            if min_dist <= 4 * SCALE * SCALE:
                total = comp_sizes[i] + comp_sizes[j] + 1
                if total > max_towers:
                    max_towers = total
    return max_towers

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_tower_coverage(dut):
    # Detect interface
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    uses_individual_ports = has_signal(dut, 'x0')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test cases: each case is a list of (x, y) tuples
    test_cases = [
        # Example 1: 5 towers that can all be connected
        [(1.0, 1.0), (3.1, 1.0), (1.0, 3.1), (3.1, 3.1), (4.2, 3.1)],
        # Example 2: 5 towers, last one far away
        [(1.0, 1.0), (3.1, 1.0), (1.0, 3.1), (3.1, 3.1), (10.0, 10.0)],
        # Additional small cases
        [(0.0, 0.0)],  # Single tower
        [(0.0, 0.0), (1.5, 0.0)],  # Two towers close
        [(0.0, 0.0), (5.0, 0.0)],  # Two towers far
        [(0.0, 0.0), (1.5, 0.0), (0.0, 1.5)],  # Three towers forming a triangle
    ]
    
    for idx, towers in enumerate(test_cases):
        n = len(towers)
        # Convert to fixed-point
        towers_fixed = [(float_to_fixed(x), float_to_fixed(y)) for x, y in towers]
        
        # Set inputs
        dut.n.value = n
        # Set coordinates for all 8 ports (pad with zeros)
        for i in range(8):
            if i < n:
                x_val, y_val = towers_fixed[i]
            else:
                x_val, y_val = 0, 0
            if has_signal(dut, f'x{i}'):
                getattr(dut, f'x{i}').value = clamp_to_width(x_val, DATA_WIDTH)
                getattr(dut, f'y{i}').value = clamp_to_width(y_val, DATA_WIDTH)
            else:
                # Fallback to array access if ports are named differently
                dut.x[i].value = clamp_to_width(x_val, DATA_WIDTH)
                dut.y[i].value = clamp_to_width(y_val, DATA_WIDTH)
        
        # Compute expected result
        expected = compute_expected(towers)
        
        if is_sequential:
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            # Wait for done
            cycles = 0
            while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                await RisingEdge(dut.clk)
                cycles += 1
                if cycles > MAX_CYCLES:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
            # Read result
            result = int(dut.result.value)
        else:
            # Combinational - wait for propagation
            await Timer(100, units='ns')
            result = int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {idx}: expected {expected}, got {result}")
        dut._log.info(f"Test {idx}: PASS (result={result})")
        
        # Reset for next test
        if is_sequential:
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
