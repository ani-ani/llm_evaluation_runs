import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
MAX_VAL = (1 << DATA_WIDTH) - 1
CLK_NS = 10
MAX_CYCLES = 5000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'edge_valid'): dut.edge_valid.value = 0
    if has_signal(dut, 'edge_end'): dut.edge_end.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def build_p_mask(insecure_list):
    mask = 0
    for b in insecure_list:
        # Buildings are 1-indexed in input, converting to 0-indexed bit position
        if 1 <= b <= 16:
            mask |= 1 << (b - 1)
    return mask

class Edge:
    def __init__(self, u, v, w):
        self.u = u - 1  # Convert to 0-indexed
        self.v = v - 1
        self.w = w

# Python reference for expected output
def python_solve(n, m, p, insecure_list, edges):
    p_mask = build_p_mask(insecure_list)
    if n == 1:
        return 0, False
    
    edges.sort(key=lambda x: x.w)
    
    parent = list(range(n))
    rank = [0] * n
    degree = [0] * n
    total_cost = 0
    edges_used = 0
    
    def find(i):
        if parent[i] != i:
            parent[i] = find(parent[i])
        return parent[i]
    
    def union(i, j):
        root_i = find(i)
        root_j = find(j)
        if root_i == root_j:
            return False
        if rank[root_i] < rank[root_j]:
            parent[root_i] = root_j
        elif rank[root_i] > rank[root_j]:
            parent[root_j] = root_i
        else:
            parent[root_j] = root_i
            rank[root_i] += 1
        return True
    
    for edge in edges:
        if find(edge.u) != find(edge.v):
            # Check degree constraint for insecure nodes
            u_insecure = (p_mask >> edge.u) & 1
            v_insecure = (p_mask >> edge.v) & 1
            
            # If an insecure node already has degree 1, it cannot accept more edges
            if u_insecure and degree[edge.u] >= 1:
                continue
            if v_insecure and degree[edge.v] >= 1:
                continue
                
            # If both are insecure and same node (shouldn't happen), skip
            # If connecting two insecure nodes, both get degree 1 (valid)
            
            union(edge.u, edge.v)
            degree[edge.u] += 1
            degree[edge.v] += 1
            total_cost += edge.w
            edges_used += 1
            
            if edges_used == n - 1:
                break
                
    if edges_used != n - 1:
        return 0, True # Impossible
        
    return total_cost, False

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_secure_network(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases
    test_cases = [
        {
            "n": 4, "m": 6, "p": 1, "insecure": [1],
            "edges": [(1,2,1), (1,3,1), (1,4,1), (2,3,2), (2,4,4), (3,4,3)],
            "expected_cost": 6, "expected_impossible": False
        },
        {
            "n": 4, "m": 3, "p": 2, "insecure": [1, 2],
            "edges": [(1,2,1), (2,3,7), (3,4,5)],
            "expected_cost": 0, "expected_impossible": True
        },
        {
            "n": 1, "m": 0, "p": 0, "insecure": [],
            "edges": [],
            "expected_cost": 0, "expected_impossible": False
        }
    ]
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: n={tc['n']}, m={tc['m']}, p={tc['p']}")
        
        # Verify with Python reference
        py_cost, py_imp = python_solve(tc['n'], tc['m'], tc['p'], tc['insecure'], [Edge(*e) for e in tc['edges']])
        
        if tc['expected_impossible'] != py_imp:
            cocotb.log.warning(f"Python ref disagrees on impossibility: expected {tc['expected_impossible']}, got {py_imp}")
        if not tc['expected_impossible'] and tc['expected_cost'] != py_cost:
             cocotb.log.warning(f"Python ref disagrees on cost: expected {tc['expected_cost']}, got {py_cost}")

        # Load Inputs
        dut.n.value = tc['n']
        dut.p_mask.value = build_p_mask(tc['insecure'])
        
        # Start Pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed Edges
        for u, v, w in tc['edges']:
            dut.edge_valid.value = 1
            dut.edge_u.value = u - 1  # Convert to 0-indexed for HDL
            dut.edge_v.value = v - 1
            dut.edge_w.value = w
            await RisingEdge(dut.clk)
        
        dut.edge_valid.value = 0
        dut.edge_end.value = 1
        await RisingEdge(dut.clk)
        dut.edge_end.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check Results
        res_val = int(dut.result.value)
        imp_val = int(dut.impossible.value)
        
        if tc['expected_impossible']:
            if imp_val != 1:
                raise TestFailure(f"Test {i+1}: Expected impossible=1, got {imp_val}")
        else:
            if imp_val != 0:
                raise TestFailure(f"Test {i+1}: Expected impossible=0, got {imp_val}")
            if res_val != tc['expected_cost']:
                raise TestFailure(f"Test {i+1}: Expected cost {tc['expected_cost']}, got {res_val}")
                
        cocotb.log.info(f"Test {i+1} Passed")
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)