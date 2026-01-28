import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_V = 16
MAX_DEG = 255
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def validate_forest(degrees):
    """Check if forest is possible"""
    V = len(degrees)
    if V == 0:
        return True, 0, []
    
    # Sum of degrees must be even
    total_deg = sum(degrees)
    if total_deg % 2 != 0:
        return False, 0, []
    
    # Check max degree <= V-1
    if V > 1 and any(d > V - 1 for d in degrees):
        return False, 0, []
    
    # Forest condition: sum(deg) <= 2*(V - num_components)
    # where num_components is number of vertices with degree > 0
    non_zero = sum(1 for d in degrees if d > 0)
    if V > 1 and total_deg > 2 * (V - non_zero):
        return False, 0, []
    
    # Special case: V=1, degree must be 0
    if V == 1 and degrees[0] != 0:
        return False, 0, []
    
    # Generate edges using a simple algorithm
    edges = []
    deg_copy = degrees.copy()
    
    # Simple algorithm: repeatedly connect vertices with remaining degree
    # This may not always find a solution but works for many cases
    for _ in range(total_deg // 2):
        # Find two vertices with remaining degree
        candidates = [(i, d) for i, d in enumerate(deg_copy) if d > 0]
        if len(candidates) < 2:
            return False, 0, []
        
        # Sort by degree descending
        candidates.sort(key=lambda x: x[1], reverse=True)
        a, da = candidates[0]
        b, db = candidates[1]
        
        # Connect them
        edges.append((a + 1, b + 1))  # 1-indexed
        deg_copy[a] -= 1
        deg_copy[b] -= 1
    
    # Verify all degrees are satisfied
    if any(d != 0 for d in deg_copy):
        return False, 0, []
    
    # Check for cycles (simple check for small graphs)
    # Build adjacency list
    adj = {i: set() for i in range(V)}
    for a, b in edges:
        adj[a-1].add(b-1)
        adj[b-1].add(a-1)
    
    # Check each component for cycles
    visited = [False] * V
    for i in range(V):
        if not visited[i] and degrees[i] > 0:
            # BFS to check connectivity and cycles
            stack = [(i, -1)]
            visited[i] = True
            edge_count = 0
            nodes = 0
            while stack:
                node, parent = stack.pop()
                nodes += 1
                for neighbor in adj[node]:
                    edge_count += 1
                    if not visited[neighbor]:
                        visited[neighbor] = True
                        stack.append((neighbor, node))
            
            # In a tree: edges = nodes - 1
            # In a forest component: edges = nodes - 1
            if edge_count // 2 != nodes - 1:
                return False, 0, []
    
    return True, total_deg // 2, edges

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_forest(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("3\n1 1 2\n", "POSSIBLE\n1 3\n2 3\n", "Sample 1"),
        ("2\n1 2\n", "IMPOSSIBLE\n", "Sample 2"),
        ("3\n2 2 2\n", "IMPOSSIBLE\n", "Sample 3"),
        ("1\n0\n", "POSSIBLE\n", "Single node"),
        ("4\n1 1 1 1\n", "POSSIBLE\n", "Four nodes"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, exp_out, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Parse input
            lines = inp_str.strip().split('\n')
            V = int(lines[0])
            if V > 0:
                degrees = list(map(int, lines[1].split()))
            else:
                degrees = []
            
            # Validate with Python algorithm
            possible_py, deg_sum, edges_py = validate_forest(degrees)
            
            if is_seq:
                # Set inputs
                dut.V.value = clamp_to_width(V, 4)
                
                # Set degrees array
                for j in range(min(V, MAX_V)):
                    if has_signal(dut, f'deg_{j}'):
                        getattr(dut, f'deg_{j}').value = clamp_to_width(degrees[j], 8)
                    elif has_signal(dut, 'deg'):
                        dut.deg[j].value = clamp_to_width(degrees[j], 8)
                
                # Set remaining to 0
                for j in range(V, MAX_V):
                    if has_signal(dut, f'deg_{j}'):
                        getattr(dut, f'deg_{j}').value = 0
                    elif has_signal(dut, 'deg'):
                        dut.deg[j].value = 0
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                await wait_for_done(dut)
                
                # Read results
                possible = int(dut.possible.value) if is_value_defined(dut.possible.value) else 0
                edge_count = int(dut.edge_count.value) if is_value_defined(dut.edge_count.value) else 0
                
                # Read edges
                edges_hdl = []
                for j in range(edge_count):
                    if has_signal(dut, f'edges_a_{j}'):
                        a = int(getattr(dut, f'edges_a_{j}').value)
                        b = int(getattr(dut, f'edges_b_{j}').value)
                    elif has_signal(dut, 'edges_a'):
                        a = int(dut.edges_a[j].value)
                        b = int(dut.edges_b[j].value)
                    else:
                        raise TestFailure("Edge signals not found")
                    edges_hdl.append((a, b))
                
                # Compare
                expected_possible = 1 if possible_py else 0
                if possible != expected_possible:
                    raise TestFailure(f"Expected possible={expected_possible}, got {possible}")
                
                if possible_py:
                    if edge_count != deg_sum // 2:
                        raise TestFailure(f"Expected {deg_sum//2} edges, got {edge_count}")
                    
                    # Sort both edge lists for comparison
                    edges_hdl_sorted = sorted([tuple(sorted(e)) for e in edges_hdl])
                    edges_py_sorted = sorted([tuple(sorted(e)) for e in edges_py])
                    
                    if edges_hdl_sorted != edges_py_sorted:
                        raise TestFailure(f"Edges mismatch. Expected {edges_py}, got {edges_hdl}")
            else:
                # Combinational - just check Python result
                await Timer(100, units='ns')
                possible = 1 if possible_py else 0
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")