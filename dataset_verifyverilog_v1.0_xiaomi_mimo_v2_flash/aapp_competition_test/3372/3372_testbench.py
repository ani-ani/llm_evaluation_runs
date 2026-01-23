import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
N_NODES = 8
DATA_WIDTH = 8
RESULT_WIDTH = 4
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

# ============================================================================
# GRAPH PARSING AND MATRIX BUILDING
# ============================================================================

def parse_graph_description(lines):
    """
    Parse airline flight description format and build adjacency matrix.
    
    Input format per line:
    - "N m a1 a2 ... am" : list of destinations
    - "C m a1 a2 ... am" : list of NOT destinations (complement)
    
    Returns: 8x8 adjacency matrix as list of lists (1=edge, 0=no edge)
    """
    matrix = [[0]*N_NODES for _ in range(N_NODES)]
    
    for i, line in enumerate(lines):
        if i >= N_NODES:
            break
            
        parts = line.strip().split()
        if not parts:
            continue
            
        conn_type = parts[0]
        m = int(parts[1])
        
        if conn_type == 'N':
            # Direct list of destinations
            destinations = [int(x) for x in parts[2:2+m]]
            for dest in destinations:
                if dest < N_NODES:
                    matrix[i][dest] = 1
                    
        elif conn_type == 'C':
            # Complement: all EXCEPT these
            excluded = set(int(x) for x in parts[2:2+m] if int(x) < N_NODES)
            for j in range(N_NODES):
                if j not in excluded and j != i:  # Usually no self-loops
                    matrix[i][j] = 1
                    
    return matrix

def python_bfs(matrix, s, t):
    """Standard BFS to verify results."""
    if s == t:
        return 0
    
    from collections import deque
    queue = deque([(s, 0)])
    visited = {s}
    
    while queue:
        node, dist = queue.popleft()
        
        for neighbor in range(N_NODES):
            if matrix[node][neighbor] and neighbor not in visited:
                if neighbor == t:
                    return dist + 1
                visited.add(neighbor)
                queue.append((neighbor, dist + 1))
    
    return None

# ============================================================================
# DUT INTERACTION
# ============================================================================

async def write_adjacency_matrix(dut, matrix):
    """Write adjacency matrix to DUT ports."""
    for i in range(N_NODES):
        # Convert row to 8-bit integer
        row_val = 0
        for j in range(N_NODES):
            if matrix[i][j]:
                row_val |= (1 << j)
        
        # Write to corresponding port
        port_name = f"adj_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = row_val
        else:
            raise TestFailure(f"Port {port_name} not found")

async def reset_dut(dut):
    """Reset DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut, s, t):
    """Start computation with given s and t."""
    dut.s.value = s
    dut.t.value = t
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_shortest_path(dut):
    """Test shortest path calculation with various graph configurations."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Wait a bit for clock to stabilize
    await Timer(50, units='ns')
    
    # Define test cases: (graph_description, s, t, expected_result, description)
    # Format: list of lines for each airport
    test_cases = [
        # Case 1: Sample Input 1 - impossible
        (
            [
                "N 1 2",
                "C 1 2",
                "N 1 3",
                "C 1 1",
            ],
            0, 1, None, "Sample 1: No path from 0 to 1"
        ),
        # Case 2: Sample Input 2 - 3 flights
        (
            [
                "N 1 2",
                "C 1 2",
                "N 1 3",
                "C 1 0",
            ],
            0, 1, 3, "Sample 2: Path 0->2->3->1 (3 flights)"
        ),
        # Case 3: Direct connection
        (
            [
                "N 1 1",
                "C 0",
                "C 0",
                "C 0",
            ],
            0, 1, 1, "Direct flight 0->1"
        ),
        # Case 4: Self-loop only (no path)
        (
            [
                "N 1 0",
                "C 0",
                "C 0",
                "C 0",
            ],
            0, 1, None, "Self-loop only, no path to 1"
        ),
        # Case 5: Complete graph (all except self)
        (
            [
                "C 1 0",
                "C 1 1",
                "C 1 2",
                "C 1 3",
            ],
            0, 3, 1, "Complete graph, direct edge exists"
        ),
        # Case 6: Two-hop path
        (
            [
                "N 1 2",
                "N 1 3",
                "N 1 1",
                "C 0",
            ],
            0, 1, 2, "Two-hop path 0->2->1"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (graph_lines, s, t, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {idx+1}: {description}")
        cocotb.log.info(f"s={s}, t={t}")
        
        try:
            # Parse graph and build matrix
            matrix = parse_graph_description(graph_lines)
            
            # Calculate expected using Python BFS
            python_result = python_bfs(matrix, s, t)
            
            # Verify expected matches Python BFS
            if expected is not None:
                if python_result != expected:
                    cocotb.log.warning(f"Test case error: expected {expected}, Python BFS got {python_result}")
            else:
                if python_result is not None:
                    cocotb.log.warning(f"Test case error: expected impossible, Python BFS got {python_result}")
            
            # Reset DUT
            await reset_dut(dut)
            
            # Write adjacency matrix
            await write_adjacency_matrix(dut, matrix)
            await Timer(10, units='ns')
            
            # Start computation
            await start_computation(dut, s, t)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            impossible = int(dut.impossible.value)
            
            # Verify
            if python_result is None:
                # Should be impossible
                if not impossible:
                    raise TestFailure(f"Expected impossible, got result={result}")
                else:
                    cocotb.log.info(f"  PASS: Correctly reported impossible")
                    passed += 1
            else:
                # Should have correct distance
                if impossible:
                    raise TestFailure(f"Expected result={python_result}, got impossible")
                elif result != python_result:
                    raise TestFailure(f"Expected result={python_result}, got {result}")
                else:
                    cocotb.log.info(f"  PASS: result={result}")
                    passed += 1
                    
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {type(e).__name__}: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
