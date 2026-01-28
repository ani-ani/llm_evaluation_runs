import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

# Graph packing helper for 32-node max
def pack_graph(adj_lists, num_nodes, max_nodes=32):
    """Pack adjacency lists into 512-bit integer (32 nodes * 16 bits each)"""
    packed = 0
    for i in range(min(num_nodes, max_nodes)):
        if i < len(adj_lists):
            adj_mask = 0
            for neighbor in adj_lists[i]:
                if neighbor < max_nodes:  # Scale to max 32 nodes
                    adj_mask |= (1 << neighbor)
            packed |= (adj_mask << (i * 16))
    return packed

# Python reference implementation for verification
def can_place_drones(k, n, adj_lists):
    """Check if k drones can be placed with no adjacent conflicts"""
    if k == 0:
        return True
    if k == 1:
        return True
    if k > n:
        return False
    
    # For small n (scaled to 32), try all combinations
    nodes = list(range(n))
    for combo in itertools.combinations(nodes, k):
        valid = True
        for i in range(k):
            for j in range(i+1, k):
                if combo[j] in adj_lists[combo[i]]:
                    valid = False
                    break
            if not valid:
                break
        if valid:
            return True
    return False

# Test cases
TEST_CASES = [
    {"k": 4, "n": 7, "adj": [
        [1, 3],          # node 0 (input index 1)
        [0, 2, 4],       # node 1
        [1],             # node 2
        [0, 4],          # node 3
        [1, 5, 3, 6],    # node 4
        [4, 6],          # node 5
        [5, 4]           # node 6
    ], "expected": False},
    {"k": 4, "n": 8, "adj": [
        [1, 3],          # node 0
        [0, 2, 4],       # node 1
        [1],             # node 2
        [0, 4],          # node 3
        [1, 5, 3, 6],    # node 4
        [4, 7],          # node 5
        [7, 5],          # node 6
        [6, 5]           # node 7
    ], "expected": True},
    {"k": 0, "n": 5, "adj": [[],[],[],[],[]], "expected": True},
    {"k": 1, "n": 5, "adj": [[1],[0],[3],[2],[0]], "expected": True},
    {"k": 2, "n": 3, "adj": [[1],[0,2],[1]], "expected": False},  # Triangle, can't place 2
    {"k": 2, "n": 4, "adj": [[1],[0,2],[1,3],[2]], "expected": True},  # Line, can place at ends
]

CLK_NS = 10
MAX_CYCLES = 1000

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_drone_placement(dut):
    # Check required signals
    required = ['clk', 'rst_n', 'start', 'k_in', 'graph_packed', 'num_nodes', 'result', 'done']
    for sig in required:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(TEST_CASES):
        cocotb.log.info(f"Test case {i+1}: k={tc['k']}, n={tc['n']}, expected={tc['expected']}")
        
        try:
            # Prepare graph
            packed = pack_graph(tc['adj'], tc['n'])
            
            # Set inputs
            dut.k_in.value = clamp_to_width(tc['k'], 4)
            dut.graph_packed.value = packed
            dut.num_nodes.value = clamp_to_width(tc['n'], 6)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            expected = 1 if tc['expected'] else 0
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between test cases
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")