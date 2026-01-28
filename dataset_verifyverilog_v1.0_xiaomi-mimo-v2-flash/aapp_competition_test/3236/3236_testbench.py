import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Fibonacci numbers pre-computed (first 16)
FIB = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987]

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

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

async def write_heights(dut, heights, DATA_WIDTH=16, ARRAY_SIZE=16):
    # Write individual height values
    for i in range(min(len(heights), ARRAY_SIZE)):
        val = clamp_to_width(heights[i], DATA_WIDTH)
        if has_signal(dut, f'heights_{i}'):
            getattr(dut, f'heights_{i}').value = val
        else:
            # Try accessing as 2D array
            try:
                dut.heights[i].value = val
            except:
                pass

async def write_adj_matrix(dut, adj_list, n, DATA_WIDTH=1, ARRAY_SIZE=256):
    # adj_list: list of (u,v) edges (0-indexed)
    # Build adjacency matrix
    adj_matrix = [[0]*n for _ in range(n)]
    for u, v in adj_list:
        if u < n and v < n and u != v:
            adj_matrix[u][v] = 1
            adj_matrix[v][u] = 1  # Undirected
    
    # Flatten to bit vector
    flat_adj = 0
    for i in range(16):
        for j in range(16):
            if i < n and j < n:
                bit = adj_matrix[i][j]
            else:
                bit = 0
            flat_adj |= (bit << (i * 16 + j))
    
    if has_signal(dut, 'adj'):
        dut.adj.value = flat_adj
    else:
        # Individual bits
        for i in range(16):
            for j in range(16):
                idx = i * 16 + j
                if hasattr(dut.adj, f'__getitem__'):
                    dut.adj[idx].value = 1 if (i < n and j < n and adj_matrix[i][j]) else 0
                else:
                    signal_name = f'adj_{i}_{j}'
                    if has_signal(dut, signal_name):
                        getattr(dut, signal_name).value = 1 if (i < n and j < n and adj_matrix[i][j]) else 0

async def write_num_nodes(dut, n):
    if has_signal(dut, 'num_nodes'):
        dut.num_nodes.value = clamp_to_width(n, 4)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fibonacci_tour(dut):
    CLK_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Input 1: 5 nodes, heights [1,3,2,1,5], edges 1-3,2-3,1-4,3-5,4-5,2-5
        # Expected: 5 (path: 1-3-5-4-? Wait, heights: 1,1,2,3,5)
        # Nodes: 0:1, 1:3, 2:2, 3:1, 4:5
        # Edges: (0,2),(1,2),(0,3),(2,4),(3,4),(1,4)
        # Path: node0(1) -> node2(2) -> node1(3) -> node4(5) -> node3(1) ??? No, must be consecutive Fibonacci
        # Let's recheck: Fib seq: 1,1,2,3,5
        # Path: node3(1) -> node0(1) -> node2(2) -> node1(3) -> node4(5)
        # Edges: 3-0 (edge 1-4? yes), 0-2 (1-3? yes), 2-1 (3-2? yes), 1-4 (2-5? yes)
        {
            "n": 5,
            "heights": [1, 3, 2, 1, 5],
            "edges": [(0,2), (1,2), (0,3), (2,4), (3,4), (1,4)],
            "expected": 5,
            "desc": "Full Fibonacci sequence 1,1,2,3,5"
        },
        # Input 2: 4 nodes, heights [4,4,8,12], edges 1-2,2-3,3-4
        # No Fibonacci subsequence > 1, so answer 1
        {
            "n": 4,
            "heights": [4, 4, 8, 12],
            "edges": [(0,1), (1,2), (2,3)],
            "expected": 1,
            "desc": "Single node tour only"
        },
        # Input 3: 3 nodes, heights [6,6,6], all connected
        # No Fibonacci subsequence (6 not in Fib), answer 0
        {
            "n": 3,
            "heights": [6, 6, 6],
            "edges": [(0,1), (0,2), (1,2)],
            "expected": 0,
            "desc": "No valid tour"
        }
    ]
    
    passed = 0
    failed = 0
    
    for idx, case in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx+1}: {case['desc']}")
        
        try:
            # Write inputs
            await write_num_nodes(dut, case['n'])
            await write_heights(dut, case['heights'])
            await write_adj_matrix(dut, case['edges'], case['n'])
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.max_len.value):
                raise TestFailure("max_len undefined")
            
            result = int(dut.max_len.value)
            expected = case['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: Got {result}")
            passed += 1
            
            # Small delay between tests
            await Timer(100, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
