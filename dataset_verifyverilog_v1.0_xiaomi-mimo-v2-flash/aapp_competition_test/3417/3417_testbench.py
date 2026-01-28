import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1500

# Helper functions from template
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def build_adj_matrix(n, edges, max_n=16):
    """Build packed adjacency matrix for n vertices"""
    matrix = 0
    for (u, v) in edges:
        # Convert to 0-indexed
        u_idx = u - 1
        v_idx = v - 1
        if u_idx < max_n and v_idx < max_n:
            matrix |= (1 << (u_idx * 16 + v_idx))
            matrix |= (1 << (v_idx * 16 + u_idx))
    return matrix

def max_independent_set_size(n, edges):
    """Python reference implementation for verification"""
    if n == 0:
        return 0
    
    # Build adjacency set
    adj = {}
    for i in range(1, n+1):
        adj[i] = set()
    
    for (u, v) in edges:
        adj[u].add(v)
        adj[v].add(u)
    
    max_size = 0
    # Iterate over all subsets
    for mask in range(1 << n):
        vertices = []
        valid = True
        for i in range(n):
            if mask & (1 << i):
                vertices.append(i+1)
        
        # Check independence
        for i, u in enumerate(vertices):
            for v in vertices[i+1:]:
                if v in adj[u]:
                    valid = False
                    break
            if not valid:
                break
        
        if valid:
            size = bin(mask).count('1')
            max_size = max(max_size, size)
    
    return max_size

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_independent_set(dut):
    """Test Maximum Independent Set module"""
    
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, edges, expected_result)
    test_cases = [
        # Single edge: 2 vertices, max independent set = 1
        (2, [(1, 2)], 1),
        # 4 vertices, edges: 1-2, 2-3, 3-4, 4-1, 1-3 (complete with extra edge)
        # This is a 4-cycle with diagonal, max independent set = 2
        (4, [(1, 2), (2, 3), (3, 4), (4, 1), (1, 3)], 2),
        # Path of 3: 1-2-3, max independent set = 2 (vertices 1 and 3)
        (3, [(1, 2), (2, 3)], 2),
        # Triangle (3-cycle): all connected, max independent set = 1
        (3, [(1, 2), (2, 3), (3, 1)], 1),
        # Single vertex (edge case)
        (1, [], 1),
        # Star graph: center connected to 3 leaves, max = 3 (leaves)
        (4, [(1, 2), (1, 3), (1, 4)], 3),
        # Isolated edge and isolated vertex: max = 2
        (3, [(1, 2)], 2),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, edges, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, edges={len(edges)}, expected={expected}")
        
        try:
            # Build adjacency matrix
            adj_matrix = build_adj_matrix(n, edges, max_n=16)
            
            if is_seq:
                # Drive inputs
                dut.n.value = n
                dut.adj_matrix.value = adj_matrix
                
                # Assert start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
                
                # Read result
                result = int(dut.result.value)
            else:
                # Combinational: assign inputs directly
                dut.n.value = n
                dut.adj_matrix.value = adj_matrix
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")
