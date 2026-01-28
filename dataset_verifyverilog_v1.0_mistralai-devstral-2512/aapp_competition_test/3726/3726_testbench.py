import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_parity(dut, parity_list):
    for i, p in enumerate(parity_list):
        if i >= 16: break
        dut.group_parity[i].value = p
    # Set group index to 0 (we assume external controller sets it; here we set num_groups)
    dut.num_groups.value = len(parity_list)

async def write_adjacency(dut, adj):
    # adj is 16x16 matrix of 0/1
    for i in range(16):
        for j in range(16):
            dut.adj_matrix[i*16 + j].value = adj[i][j]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_card_flip(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Helper to compute expected answer
    def compute_expected(parity, adj):
        e = sum(1 for p in parity if p == 1)
        o = len(parity) - e
        # Build bipartite graph: even indices vs odd indices
        even_nodes = [i for i, p in enumerate(parity) if p == 1]
        odd_nodes = [i for i, p in enumerate(parity) if p == 0]
        # Build adjacency list
        adj_list = [[] for _ in even_nodes]
        for ei, e_node in enumerate(even_nodes):
            for oi, o_node in enumerate(odd_nodes):
                if adj[e_node][o_node]:
                    adj_list[ei].append(oi)
        # Maximum bipartite matching (simple DFS)
        match_odd = [-1] * len(odd_nodes)  # which even node matched to odd
        def dfs(u, visited):
            for v in adj_list[u]:
                if not visited[v]:
                    visited[v] = True
                    if match_odd[v] == -1 or dfs(match_odd[v], visited):
                        match_odd[v] = u
                        return True
            return False
        match_count = 0
        for u in range(len(even_nodes)):
            visited = [False] * len(odd_nodes)
            if dfs(u, visited):
                match_count += 1
        f = match_count
        rem_e = e - f
        rem_o = o - f
        answer = f + 2*((rem_e//2) + (rem_o//2)) + 3*(rem_e % 2)
        return answer
    
    # Test cases
    test_cases = [
        # (parity list, adjacency matrix, description)
        # Example: N=2, cards 4,5 -> groups: [4] (even), [5] (odd)
        ([1, 0], [[0,1],[1,0]], "Sample 4,5"),
        # Example: N=1, card 1 -> group [1] (odd)
        ([0], [[0]], "Single card 1"),
        # Example: N=2, cards 1,2 -> groups: [1] (odd), [2] (even)
        ([0,1], [[0,1],[1,0]], "1,2"),
        # Example: N=2, cards 2,3 -> groups: [2] (even), [3] (odd)
        ([1,0], [[0,1],[1,0]], "2,3"),
        # Larger example: 4 groups, 2 even, 2 odd, with matching possible
        ([1,0,1,0], [[0,1,0,0],[1,0,0,0],[0,0,0,1],[0,0,1,0]], "Four groups")
    ]
    
    passed = 0
    failed = 0
    
    for i, (parity, adj, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Compute expected
            exp = compute_expected(parity, adj)
            
            # Write inputs
            await write_parity(dut, parity)
            await write_adjacency(dut, adj)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")