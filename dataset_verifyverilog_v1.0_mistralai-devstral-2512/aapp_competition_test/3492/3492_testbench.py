import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_NODES = 16
NODE_WIDTH = 4
EDGE_WIDTH = 6
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 4096

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

# Array packing helpers
def pack_edges(u_list, v_list, cap_list, node_bits=4, edge_bits=6):
    """Pack edge lists into 64-bit vectors"""
    u_packed = 0
    v_packed = 0
    cap_packed = 0
    
    for i, (u, v, cap) in enumerate(zip(u_list, v_list, cap_list)):
        if i >= (1 << edge_bits):
            break
        u_packed |= (u & ((1 << node_bits) - 1)) << (i * node_bits)
        v_packed |= (v & ((1 << node_bits) - 1)) << (i * node_bits)
        cap_packed |= (cap & 1) << i
    
    return u_packed, v_packed, cap_packed

def max_flow_bruteforce(num_nodes, edges):
    """Brute-force max flow for verification (Edmonds-Karp with BFS)"""
    # Build adjacency matrix
    capacity = [[0] * num_nodes for _ in range(num_nodes)]
    for u, v, cap in edges:
        if u < num_nodes and v < num_nodes:
            capacity[u][v] = cap
    
    source = 0
    sink = num_nodes - 1
    flow = 0
    
    while True:
        # BFS to find augmenting path
        parent = [-1] * num_nodes
        visited = [False] * num_nodes
        queue = [source]
        visited[source] = True
        
        found = False
        while queue:
            u = queue.pop(0)
            if u == sink:
                found = True
                break
            for v in range(num_nodes):
                if not visited[v] and capacity[u][v] > 0:
                    visited[v] = True
                    parent[v] = u
                    queue.append(v)
        
        if not found:
            break
        
        # Find bottleneck
        path_flow = float('inf')
        v = sink
        while v != source:
            u = parent[v]
            path_flow = min(path_flow, capacity[u][v])
            v = u
        
        # Update flow
        v = sink
        while v != source:
            u = parent[v]
            capacity[u][v] -= path_flow
            capacity[v][u] += path_flow
            v = u
        
        flow += path_flow
    
    return flow

# Testbench template
def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_max_flow(dut):
    # Check sequential
    is_seq = has_signal(dut, 'clk')
    
    # Setup clock
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - just reset
        dut.rst_n.value = 0
        await Timer(10, units='ns')
        dut.rst_n.value = 1
    
    # Test cases
    test_cases = [
        # Simple matching: supplier 1->factory 1
        {
            'desc': 'Simple 1-1 matching',
            'num_nodes': 4,
            'edges': [(1, 2, 1), (0, 1, 1), (2, 3, 1)],  # S->A->F->Sink
            'expected': 1
        },
        # Supplier 1->Factory 1, Supplier 2->Factory 2
        {
            'desc': 'Two disjoint paths',
            'num_nodes': 5,
            'edges': [(0, 1, 1), (0, 2, 1), (1, 3, 1), (2, 4, 1)],  # S->F1->Sink, S->F2->Sink
            'expected': 2
        },
        # Supplier 1 can go to both, Supplier 2 to one
        {
            'desc': 'Bipartite sharing',
            'num_nodes': 5,
            'edges': [(0, 1, 1), (0, 2, 1), (1, 3, 1), (1, 4, 1), (2, 3, 1)],
            'expected': 2
        },
        # Original example scaled down
        {
            'desc': 'Original example adapted',
            'num_nodes': 8,
            'edges': [
                (0, 1, 1),  # Supplier A -> State 1
                (0, 2, 1),  # Supplier B -> State 2  
                (0, 3, 1),  # Supplier C -> State 3
                (1, 4, 1),  # State 1 -> Factory D
                (2, 5, 1),  # State 2 -> Factory E
                (3, 6, 1),  # State 3 -> Factory F
                (7, 6, 1),  # Factory F -> Sink (simplified)
            ],
            'expected': 2
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {tc['desc']}")
        
        try:
            num_nodes = tc['num_nodes']
            edges = tc['edges']
            expected = tc['expected']
            
            # Prepare edge data
            u_list = []
            v_list = []
            cap_list = []
            
            for u, v, cap in edges:
                u_list.append(clamp_to_width(u, NODE_WIDTH))
                v_list.append(clamp_to_width(v, NODE_WIDTH))
                cap_list.append(cap & 1)
            
            # Add padding
            num_edges = len(edges)
            while len(u_list) < 64:
                u_list.append(0)
                v_list.append(0)
                cap_list.append(0)
            
            # Pack edges
            u_packed, v_packed, cap_packed = pack_edges(u_list, v_list, cap_list)
            
            if is_seq:
                # Set inputs
                dut.num_nodes.value = clamp_to_width(num_nodes, 4)
                dut.num_edges.value = clamp_to_width(num_edges, 6)
                dut.edge_u.value = u_packed
                dut.edge_v.value = v_packed
                dut.capacity.value = cap_packed
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done = False
                for cycle in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                
                # Read result
                result = int(dut.max_flow.value) if is_value_defined(dut.max_flow.value) else 0
            else:
                # Combinational
                dut.num_nodes.value = clamp_to_width(num_nodes, 4)
                dut.num_edges.value = clamp_to_width(num_edges, 6)
                dut.edge_u.value = u_packed
                dut.edge_v.value = v_packed
                dut.capacity.value = cap_packed
                
                await Timer(100, units='ns')
                
                result = int(dut.max_flow.value) if is_value_defined(dut.max_flow.value) else 0
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} (PASS)")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")