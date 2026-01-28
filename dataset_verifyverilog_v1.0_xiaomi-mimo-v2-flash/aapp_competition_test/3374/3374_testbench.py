import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    if v < 0: v = 0
    return min((1 << bits) - 1, v)

# Python Reference Implementation for verification
def python_ref(num_nodes, gravities, adj_matrix, types):
    INF = 1 << 31
    min_dist = INF
    
    # Helper to compute path cost
    def compute_path_cost(path):
        if len(path) < 2:
            return INF
        g_seq = [gravities[i] for i in path]
        # Cap
        cap = [g_seq[i+1] + g_seq[i] for i in range(len(g_seq)-1)]
        # Pot (abs diff)
        pot = [abs(g_seq[i+1] - g_seq[i]) for i in range(len(g_seq)-1)]
        # Ind (truncate to 16 bits)
        ind = [(g_seq[i+1] * g_seq[i]) & 0xFFFF for i in range(len(g_seq)-1)]
        # Cap * Cap
        cap_cap = [(c * c) & 0xFFFF for c in cap]
        # Term = Cap*Cap - Ind
        term = [(cc - ind[i]) & 0xFFFF for i, cc in enumerate(cap_cap)]
        # Prod = Pot * Term (32-bit)
        prod = [pot[i] * term[i] for i in range(len(pot))]
        # Sum
        return sum(prod)

    # Iterate all device placements (None is -1)
    for device_node in list(range(num_nodes)) + [-1]:
        # Modify gravities based on device
        mod_grav = list(gravities)
        if device_node != -1:
            # Decrease self
            mod_grav[device_node] = max(1, mod_grav[device_node] - 1)
            # Increase neighbors
            for n in range(num_nodes):
                if adj_matrix[device_node * num_nodes + n]:
                    mod_grav[n] = min(65535, mod_grav[n] + 1)
        
        # Iterate all pairs u, v
        for u in range(num_nodes):
            for v in range(num_nodes):
                if types[u] == types[v]:
                    continue
                
                # 1. Direct path
                if adj_matrix[u * num_nodes + v] or adj_matrix[v * num_nodes + u]:
                    dist = compute_path_cost([u, v])
                    if dist < min_dist:
                        min_dist = dist
                
                # 2. 2-hop path (u -> k -> v)
                for k in range(num_nodes):
                    if k == u or k == v:
                        continue
                    if (adj_matrix[u * num_nodes + k] or adj_matrix[k * num_nodes + u]) and \
                       (adj_matrix[k * num_nodes + v] or adj_matrix[v * num_nodes + k]):
                        dist = compute_path_cost([u, k, v])
                        if dist < min_dist:
                            min_dist = dist
    return min_dist

# Testbench
DATA_WIDTH = 16
NUM_NODES_MAX = 16
CLK_NS = 10
MAX_CYCLES = 2000

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_unterwave(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1 (From Example)
    num_nodes = 9
    gravities = [377, 455, 180, 211, 134, 46, 111, 213, 17]
    types_str = ['a', 'h', 'a', 'a', 'a', 'h', 'h', 'h', 'a']
    types = [0 if t == 'a' else 1 for t in types_str]
    
    # Adjacency list
    edges = [
        (1,2), (1,4), (1,6), (2,3), (2,4), (2,5), (3,5), 
        (4,6), (4,7), (4,9), (5,7), (5,8), (6,9), (7,9), (7,8)
    ]
    # Convert to 0-indexed flattened matrix
    adj_matrix = [0] * (NUM_NODES_MAX * NUM_NODES_MAX)
    for u, v in edges:
        u -= 1; v -= 1
        adj_matrix[u * NUM_NODES_MAX + v] = 1
        adj_matrix[v * NUM_NODES_MAX + u] = 1

    # Calculate Expected
    expected = python_ref(num_nodes, gravities, adj_matrix, types)
    
    cocotb.log.info(f"Test Case 1: Expected {expected}")
    
    # Write Inputs
    dut.num_nodes.value = num_nodes
    
    # Write Gravity (0-indexed for logic, but input is 1-indexed)
    # We only fill up to num_nodes, rest are 0
    for i in range(NUM_NODES_MAX):
        val = gravities[i] if i < num_nodes else 0
        dut.gravity[i].value = clamp_to_width(val, DATA_WIDTH)
        
    # Write Types
    type_val = 0
    for i in range(num_nodes):
        if types[i] == 1: # Human
            type_val |= (1 << i)
    dut.types.value = type_val
    
    # Write Adj Matrix
    for i in range(NUM_NODES_MAX * NUM_NODES_MAX):
        dut.adj_matrix[i].value = adj_matrix[i]
        
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    done = False
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Timeout waiting for done")
    
    result = int(dut.result.value)
    cocotb.log.info(f"Result: {result}")
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    # Test Case 2 (Small, zero distance)
    await reset_dut(dut)
    num_nodes = 3
    gravities = [20, 21, 19]
    types = [1, 1, 0] # h, h, a
    adj_matrix = [0] * (NUM_NODES_MAX * NUM_NODES_MAX)
    edges = [(1,2), (2,3), (3,1)]
    for u, v in edges:
        u -= 1; v -= 1
        adj_matrix[u * NUM_NODES_MAX + v] = 1
        adj_matrix[v * NUM_NODES_MAX + u] = 1
        
    expected = python_ref(num_nodes, gravities, adj_matrix, types)
    
    dut.num_nodes.value = num_nodes
    for i in range(NUM_NODES_MAX):
        val = gravities[i] if i < num_nodes else 0
        dut.gravity[i].value = clamp_to_width(val, DATA_WIDTH)
    
    type_val = 0
    for i in range(num_nodes):
        if types[i] == 1:
            type_val |= (1 << i)
    dut.types.value = type_val
    
    for i in range(NUM_NODES_MAX * NUM_NODES_MAX):
        dut.adj_matrix[i].value = adj_matrix[i]
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Timeout waiting for done")
        
    result = int(dut.result.value)
    cocotb.log.info(f"Test Case 2 Result: {result}")
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
