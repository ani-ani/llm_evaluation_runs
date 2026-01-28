import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration for N=8 (scaled down from 13 for resource constraints)
N = 8
INF = 0xFFFFFF
DATA_WIDTH = 24
ADDR_WIDTH = 3
CLK_NS = 10
MAX_CYCLES = 200000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    # Handle signed/unsigned? Using unsigned for cost here.
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

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

# Helper to load the cost matrix into the DUT
async def load_graph(dut, adj_matrix):
    # adj_matrix is N x N list of costs
    dut.config_valid.value = 0
    await RisingEdge(dut.clk)
    
    for i in range(N):
        for j in range(N):
            dut.config_addr.value = (i << 3) | j  # Assuming addr encodes i,j
            dut.config_data.value = clamp_to_width(adj_matrix[i][j], DATA_WIDTH)
            dut.config_valid.value = 1
            await RisingEdge(dut.clk)
    
    dut.config_valid.value = 0
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_flight_planner(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # --- Test Case 1 (Adapted for N=8) ---
    # Original: 5 nodes. 
    # Nodes: 1(Stockholm), 2, 3, 4, 5
    # Edges: 1-2(1000), 2-3(1000), 4-5(500)
    # Add: 1-4(300), 3-5(300)
    # Target: Visit all nodes (1,2,3,4,5). 
    # Path: 1-2-3-5-4-1. Cost: 1000+1000+300+500+300 = 3100.
    
    # Create adjacency matrix for N=8 (others INF)
    adj = [[INF] * N for _ in range(N)]
    for i in range(N):
        adj[i][i] = 0
        
    def add_edge(u, v, cost):
        adj[u-1][v-1] = cost
        adj[v-1][u-1] = cost
    
    add_edge(1, 2, 1000)
    add_edge(2, 3, 1000)
    add_edge(4, 5, 500)
    add_edge(1, 4, 300)
    add_edge(3, 5, 300)
    
    # Required mask: nodes 1-5 (bits 0-4 set) = 0x1F
    required_mask = 0x1F
    
    # Load Data
    dut.log.info("Loading graph...")
    await load_graph(dut, adj)
    
    # Set required mask (assuming a dedicated input or part of config)
    # For this test, let's assume 'config_addr' 0x80 sets the mask
    dut.config_addr.value = 0x80
    dut.config_data.value = required_mask
    dut.config_valid.value = 1
    await RisingEdge(dut.clk)
    dut.config_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Start
    dut.log.info("Starting computation...")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check Result
    result = int(dut.result.value)
    dut.log.info(f"Result: {result}")
    
    # Expected: 3100
    if result != 3100:
        raise TestFailure(f"Expected 3100, got {result}")

    # --- Test Case 2 ---
    # 6 nodes: 1-2, 2-3, 1-3, 2-4 (1000), 5-6 (500)
    # Add: 2-5 (300), 4-6 (300)
    # Required: 1,2,3,4,5,6 (0x3F)
    # Path logic: 1-2-5-6-4-2-3-1 (Revisiting 2 allowed, must cover all)
    # Cost: 1000(1-2) + 300(2-5) + 500(5-6) + 300(6-4) + 1000(4-2) + 1000(2-3) + 1000(3-1)
    # Wait, let's look at example output 5100.
    # Shortest paths logic (Floyd):
    # 1-2: 1000
    # 1-3: 1000
    # 2-3: 1000
    # 2-4: 1000
    # 5-6: 500
    # 2-5: 300 -> 1-5: 1300, 3-5: 1300
    # 4-6: 300 -> 2-6: 1300 (via 4), 5-4: 800 (5-6-4)
    # TSP on {1,2,3,4,5,6}.
    # Path: 1 -> 3 -> 2 -> 4 -> 6 -> 5 -> 2 -> 1 (Revisiting 2)
    # Cost: 1000 + 1000 + 1000 + 300 + 500 + 300 + 1000 = 5100. (Matches)
    
    dut.log.info("Resetting for Test Case 2...")
    await reset_dut(dut)
    
    adj2 = [[INF] * N for _ in range(N)]
    for i in range(N):
        adj2[i][i] = 0
        
    def add_edge2(u, v, cost):
        adj2[u-1][v-1] = cost
        adj2[v-1][u-1] = cost
        
    add_edge2(1, 2, 1000)
    add_edge2(2, 3, 1000)
    add_edge2(1, 3, 1000)
    add_edge2(2, 4, 1000)
    add_edge2(5, 6, 500)
    add_edge2(2, 5, 300)
    add_edge2(4, 6, 300)
    
    await load_graph(dut, adj2)
    
    required_mask2 = 0x3F # Nodes 1-6
    dut.config_addr.value = 0x80
    dut.config_data.value = required_mask2
    dut.config_valid.value = 1
    await RisingEdge(dut.clk)
    dut.config_valid.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result2 = int(dut.result.value)
    dut.log.info(f"Result 2: {result2}")
    
    if result2 != 5100:
        raise TestFailure(f"Expected 5100, got {result2}")