import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 12000
MOD = 1000000007

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
    return min((1 << bits) - 1, max(0, v))

def pack_edge(source, dest, length):
    # Pack into 32 bits: 16 unused, 5 dest, 5 src, 6 length
    src = clamp_to_width(source, 5)
    dst = clamp_to_width(dest, 5)
    lng = clamp_to_width(length, 6)
    return (dst << 5) | src | (lng << 10)  # Note: re-arranging for clarity

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.edge_done.value) and int(dut.edge_done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def read_results(dut, num_edges):
    results = []
    cycles = 0
    while len(results) < num_edges and cycles < MAX_CYCLES:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            val = int(dut.result.value) % MOD
            results.append(val)
        cycles += 1
    if len(results) < num_edges:
        raise TestFailure(f"Only got {len(results)} results, expected {num_edges}")
    return results

@cocotb.test(timeout_time=15000, timeout_unit="ms")
async def test_shortest_path_count(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational (unlikely for this problem)
        await Timer(100, units='ns')
    
    # Test case 1: Sample 1
    # 4 nodes, 3 edges: 1->2(5), 2->3(5), 3->4(5)
    # All paths: 1->2->3->4 only. Each edge used once. But output says 3,4,3
    # This implies counting shortest paths between ALL pairs.
    # Paths: 1->2, 2->3, 3->4, 1->3, 2->4, 1->4 (6 pairs)
    # Edge 1->2: used in 1->2, 1->3, 1->4 -> 3 times
    # Edge 2->3: used in 2->3, 1->3, 2->4, 1->4 -> 4 times
    # Edge 3->4: used in 3->4, 2->4, 1->4 -> 3 times
    
    num_nodes = 4
    num_edges = 3
    edges = [
        (1, 2, 5),
        (2, 3, 5),
        (3, 4, 5)
    ]
    
    if has_signal(dut, 'num_nodes'):
        dut.num_nodes.value = num_nodes
        dut.num_edges.value = num_edges
        
        # Set edge inputs
        for i, (s, d, l) in enumerate(edges):
            packed = pack_edge(s, d, l)
            # Find port name, handle array or individual signals
            if hasattr(dut, 'edge_in'):
                dut.edge_in[i].value = packed
            else:
                port = getattr(dut, f'edge_in_{i}', None)
                if port:
                    port.value = packed
                else:
                    # Try edge_in[i] indexing if it's a wire array
                    try:
                        dut.edge_in[i].value = packed
                    except:
                        raise TestFailure(f"Cannot access edge input {i}")
    else:
        raise TestFailure("Missing num_nodes input")

    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for results
        results = await read_results(dut, num_edges)
        
        expected = [3, 4, 3]
        for i, (got, exp) in enumerate(zip(results, expected)):
            if got != exp:
                raise TestFailure(f"Edge {i}: Expected {exp}, got {got}")
                
        # Wait for edge_done
        await wait_for_done(dut)
    
    cocotb.log.info("Test 1 passed")

    # Test case 2: Sample 2
    # 4 nodes, 4 edges: 1->2(5), 2->3(5), 3->4(5), 1->4(8)
    # Shortest paths:
    # 1->2, 1->3 (via 2), 1->4 (via 1->4: 8, vs 1->2->3->4: 15 -> use 1->4)
    # 2->3, 2->4 (via 3), 3->4
    # Edge counts:
    # 1->2: used in 1->2, 1->3 -> 2 times
    # 2->3: used in 2->3, 1->3, 2->4 -> 3 times
    # 3->4: used in 3->4, 2->4 -> 2 times
    # 1->4: used in 1->4 -> 1 time
    
    await reset_dut(dut)
    num_nodes = 4
    num_edges = 4
    edges = [
        (1, 2, 5),
        (2, 3, 5),
        (3, 4, 5),
        (1, 4, 8)
    ]
    
    dut.num_nodes.value = num_nodes
    dut.num_edges.value = num_edges
    for i, (s, d, l) in enumerate(edges):
        packed = pack_edge(s, d, l)
        if hasattr(dut, 'edge_in'):
            dut.edge_in[i].value = packed
        else:
            port = getattr(dut, f'edge_in_{i}', None)
            if port: port.value = packed
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        results = await read_results(dut, num_edges)
        expected = [2, 3, 2, 1]
        for i, (got, exp) in enumerate(zip(results, expected)):
            if got != exp:
                raise TestFailure(f"Test 2 Edge {i}: Expected {exp}, got {got}")
        
        await wait_for_done(dut)
    
    cocotb.log.info("Test 2 passed")
    
    # Note: Sample 3 (5 nodes, 8 edges) is too large for N=16 constraint if we strictly follow
    # However, the prompt says N<=16, so 5 nodes is fine. 
    # But check if we have 8 edge ports available. Assuming we do.
    
    await reset_dut(dut)
    num_nodes = 5
    num_edges = 8
    edges = [
        (1, 2, 20),
        (1, 3, 2),
        (2, 3, 2),
        (4, 2, 3),
        (4, 2, 3),  # Duplicate edge in input
        (3, 4, 5),
        (4, 3, 5),
        (5, 4, 20)
    ]
    expected_output = [0, 4, 6, 6, 6, 7, 2, 6]
    
    dut.num_nodes.value = num_nodes
    dut.num_edges.value = num_edges
    for i, (s, d, l) in enumerate(edges):
        packed = pack_edge(s, d, l)
        if hasattr(dut, 'edge_in'):
            # Ensure we don't overflow array size if testbench expects less
            if i < len(dut.edge_in):
                dut.edge_in[i].value = packed
        else:
            port = getattr(dut, f'edge_in_{i}', None)
            if port: port.value = packed
            
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        results = await read_results(dut, num_edges)
        for i, (got, exp) in enumerate(zip(results, expected_output)):
            if got != exp:
                raise TestFailure(f"Test 3 Edge {i}: Expected {exp}, got {got}")
                
        await wait_for_done(dut)
    
    cocotb.log.info("All tests passed")
