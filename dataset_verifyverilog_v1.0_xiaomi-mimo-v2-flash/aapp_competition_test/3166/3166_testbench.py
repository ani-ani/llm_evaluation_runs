import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for n=16
DATA_WIDTH = 1
N = 16
CLK_NS = 10
MAX_CYCLES = 2000

# Helpers

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

# Convert 2D adjacency matrix to packed 1D vector for HDL
# adj[i][j] -> bit index i*16 + j

def pack_adj(adj_matrix):
    packed = 0
    for i in range(N):
        for j in range(N):
            if adj_matrix[i][j] == 1:
                idx = i * N + j
                packed |= (1 << idx)
    return packed

# Parse input string to get adj matrix and S list

def parse_input(input_str):
    lines = input_str.strip().split('\n')
    first_line = lines[0].split()
    n = int(first_line[0])
    k = int(first_line[1])
    
    adj_matrix = []
    for i in range(n):
        row = list(map(int, lines[i+1].split()))
        adj_matrix.append(row)
    
    s_list = list(map(int, lines[n+1].split()))
    return n, k, adj_matrix, s_list

# Create S mask

def create_s_mask(s_list):
    mask = 0
    for s in s_list:
        mask |= (1 << s)
    return mask

# Cycle check logic (simulating HDL Kahn's algorithm)
# Returns True if acyclic

def is_dag(adj_packed, active_mask, n):
    # Compute in-degrees for active nodes
    in_degree = {}
    nodes = []
    
    # Extract nodes
    for i in range(n):
        if (active_mask >> i) & 1:
            nodes.append(i)
            in_degree[i] = 0
    
    if not nodes:
        return True
        
    # Calculate in-degrees
    for i in nodes:
        for j in nodes:
            if i == j: continue
            # Check if edge i -> j exists (adj[i][j] = 1)
            idx = i * n + j
            if (adj_packed >> idx) & 1:
                in_degree[j] += 1
    
    # Kahn's algorithm
    queue = [n for n in nodes if in_degree[n] == 0]
    count = 0
    
    while queue:
        u = queue.pop(0)
        count += 1
        for v in nodes:
            if u == v: continue
            idx = u * n + v
            if (adj_packed >> idx) & 1:
                in_degree[v] -= 1
                if in_degree[v] == 0:
                    queue.append(v)
    
    return count == len(nodes)

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_tournament(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        dut.rst_n.value = 1
        dut.start.value = 0
        await Timer(CLK_NS * 2, units='ns')
        
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_inputs = [
        "4 2\n0 0 1 1\n1 0 0 1\n0 1 0 0\n0 0 1 0\n0 2\n",
        "4 2\n0 0 1 1\n1 0 0 1\n0 1 0 0\n0 0 1 0\n1 2\n",
        "5 3\n0 1 1 0 1\n0 0 1 1 0\n0 0 0 0 1\n1 0 1 0 1\n0 1 0 0 0\n0 1 2\n"
    ]
    
    expected_outputs = [1, "impossible", 2]
    
    for test_idx, (input_str, expected) in enumerate(zip(test_inputs, expected_outputs)):
        cocotb.log.info(f"Running Test Case {test_idx + 1}")
        
        n, k, adj_matrix, s_list = parse_input(input_str)
        
        # Although module is hardcoded for N=16, we adapt inputs for small n (<=16)
        # We map the n x n matrix to the top-left of 16x16
        packed_adj = pack_adj(adj_matrix)
        s_mask = create_s_mask(s_list)
        
        # Feed inputs
        if has_signal(dut, 'adj'):
            dut.adj.value = packed_adj
        else:
            # Handle split inputs if needed (rare for this spec, but good practice)
            pass
            
        if has_signal(dut, 'S_mask'):
            dut.S_mask.value = s_mask
        
        if has_signal(dut, 'k'):
            dut.k.value = k
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait for done
        if has_signal(dut, 'done'):
            done = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Test {test_idx + 1} timed out")
        else:
            await Timer(100, units='ns')
        
        # Read result
        if has_signal(dut, 'result'):
            result_val = int(dut.result.value)
        else:
            result_val = 0
            
        if has_signal(dut, 'found'):
            found_val = int(dut.found.value)
        else:
            found_val = 1 # Default to found if no signal
        
        # Validate
        if isinstance(expected, int):
            if not found_val:
                raise TestFailure(f"Test {test_idx + 1} expected {expected}, but got NOT_FOUND")
            if result_val != expected:
                raise TestFailure(f"Test {test_idx + 1} expected {expected}, got {result_val}")
        else:
            # Expected 'impossible'
            if found_val:
                raise TestFailure(f"Test {test_idx + 1} expected impossible, but found result {result_val}")
            
        cocotb.log.info(f"Test {test_idx + 1} Passed")
