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
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH HELPERS
# ============================================================================

def parse_input(input_str):
    """Parse the problem input and return m, n, list of edges (0-indexed)."""
    lines = input_str.strip().split('\n')
    first_line = lines[0].split()
    m = int(first_line[0])
    n = int(first_line[1])
    resources_per_island = []
    for i in range(1, m+1):
        line = lines[i].strip().split()
        if line and line[-1] == '0':
            line = line[:-1]
        resources = [int(x) for x in line]
        resources_per_island.append(resources)
    # Build edge list
    resource_to_islands = {}
    for island_idx, resources in enumerate(resources_per_island):
        for r in resources:
            if r not in resource_to_islands:
                resource_to_islands[r] = []
            resource_to_islands[r].append(island_idx)
    edges = []
    for r in range(1, n+1):
        islands = resource_to_islands.get(r, [])
        if len(islands) == 2:
            u, v = islands[0], islands[1]
            edges.append((u, v))
        else:
            # Should not happen in valid input; add dummy
            edges.append((0, 0))
    return m, n, edges

def is_bipartite(m, edges):
    """Check if the graph is bipartite using BFS."""
    if m == 0:
        return True
    adj = [[] for _ in range(m)]
    for u, v in edges:
        if u == v:
            return False  # self-loop
        adj[u].append(v)
        adj[v].append(u)
    color = [0] * m
    for i in range(m):
        if color[i] == 0:
            color[i] = 1
            stack = [i]
            while stack:
                node = stack.pop()
                for neighbor in adj[node]:
                    if color[neighbor] == 0:
                        color[neighbor] = 3 - color[node]
                        stack.append(neighbor)
                    elif color[neighbor] == color[node]:
                        return False
    return True

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_coexist(dut):
    """Test the coexist_checker module."""

    # Constants matching the Verilog design
    MAX_M = 8
    MAX_N = 8
    IDX_WIDTH = 3
    N_WIDTH = 3

    # Detect interface and start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset sequence
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Our module is sequential, so clock is mandatory
        raise TestFailure("Clock signal not found")

    # Test cases
    test_inputs = [
        "8 8\n0\n2 4 0\n1 8 0\n8 5 0\n4 3 7 0\n5 2 6 0\n1 6 0\n7 3 0\n",
        "4 6\n4 3 0\n6 0\n1 2 6 5 4 0\n2 5 1 3 0\n"
    ]
    expected_outputs = ["YES\n", "NO\n"]

    for test_idx, (input_str, expected_str) in enumerate(zip(test_inputs, expected_outputs)):
        dut._log.info(f"Running test case {test_idx+1}")

        # Parse and verify with Python
        m, n, edges = parse_input(input_str)
        py_result = is_bipartite(m, edges)
        expected = (expected_str.strip() == "YES")
        if py_result != expected:
            dut._log.error(f"Python result mismatch: expected {expected}, got {py_result}")
            raise TestFailure(f"Python check failed for test {test_idx+1}")

        # Set m and n
        dut.m.value = m
        dut.n.value = n

        # Clear all edge ports
        for i in range(MAX_N):
            getattr(dut, f'edge_u_{i}').value = 0
            getattr(dut, f'edge_v_{i}').value = 0

        # Set edges (already 0-indexed from parse_input)
        for i, (u, v) in enumerate(edges):
            if i < MAX_N:
                getattr(dut, f'edge_u_{i}').value = u
                getattr(dut, f'edge_v_{i}').value = v
            else:
                dut._log.warning(f"Too many edges, truncating at {MAX_N}")
                break

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        done = False
        for _ in range(1000):  # timeout cycles
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break

        if not done:
            raise TestFailure(f"Test {test_idx+1}: done not asserted")

        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {test_idx+1}: result is undefined")

        result = int(dut.result.value)
        expected_bit = 1 if expected else 0
        if result != expected_bit:
            raise TestFailure(f"Test {test_idx+1}: expected {expected_bit}, got {result}")

        dut._log.info(f"Test {test_idx+1}: PASS")

        # Wait a cycle before next test
        await RisingEdge(dut.clk)

    dut._log.info("All tests passed")
