import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Constants
CLK_NS = 10
DATA_WIDTH = 16
MAX_CYCLES = 10000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_travelling_salesman(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic
        await Timer(10, units='ns')

    # Test Case 1: Example from prompt
    # N=5, R=3. Scaled to N=8.
    # Required flights: 1-2 (1000), 2-3 (1000), 4-5 (500)
    # Additional flights: 1-4 (300), 3-5 (300)
    # Stockholm = Node 1 (Index 0)
    # Required nodes: {0, 1, 2, 3, 4} -> Map to {0, 1, 2, 3, 4}
    # Path: 0->1 (1000), 1->2 (1000), 2->4 (dist 300 via 3), 4->3 (500), 3->0 (dist 1000? No, need return)
    # Let's trace optimal: 0->1 (1000), 1->2 (1000), 2->4 (300 via add flight 3-5? No 2->3->5->4?)
    # Actually, nodes are 1,2,3,4,5. Indices 0..4.
    # Dist matrix (Floyd-Warshall) would compute:
    # 0-1: 1000, 1-2: 1000, 3-4: 500
    # Add: 0-3: 300, 2-4: 300
    # Shortest paths:
    # 0->1: 1000
    # 0->2: 2000 (0-1-2)
    # 0->3: 300
    # 0->4: 600 (0-3-4)
    # 1->2: 1000
    # 1->3: 1300 (1-0-3)
    # 1->4: 1600
    # 2->3: 600 (2-4-3? No 2-5-4-3? Wait, 2-5 is 300, 5-4 is 500. No, 2-5 is 300 (input says 3-5 is 300, so 2-4 is 300? No, 2-5 is 300).
    # Input: 3-5 (300). 4-5 (500). So 3-4 is 500. 2-3 is 1000.
    # Wait, input nodes: 1,2,3,4,5.
    # Map 1->0, 2->1, 3->2, 4->3, 5->4.
    # Req: 0-1(1000), 1-2(1000), 3-4(500).
    # Add: 0-3(300), 2-4(300).
    # Distances:
    # 0-1: 1000
    # 1-2: 1000
    # 3-4: 500
    # 0-3: 300
    # 2-4: 300
    # Shortest Paths (Floyd-Warshall logic):
    # 0 -> 1: 1000
    # 0 -> 2: 2000 (0-1-2) OR 0->3->4->2? 300+500+300=1100. YES.
    # 0 -> 3: 300
    # 0 -> 4: 600 (0->3->4: 300+500) OR (0->1->2->4: 1000+1000+300) -> 800. Wait.
    # Let's re-evaluate 0->4. 0->1->2->4: 1000+1000+300 = 2300.
    # 0->3->4: 300+500 = 800.
    # 1 -> 4: 1->2->4 (1000+300=1300) OR 1->0->3->4 (1000+300+500=1800) -> 1300.
    # 2 -> 3: 2->4->3 (300+500=800) OR 2->1->0->3 (1000+1000+300=2300) -> 800.
    # Start at 0. Must visit 0, 1, 2, 3, 4.
    # This is TSP on 5 nodes.
    # Path: 0->3->4->2->1->0.
    # Cost: 0-3(300) + 3-4(500) + 4-2(300) + 2-1(1000) + 1-0(1000) = 300+500+300+1000+1000 = 3100. Matches output.

    # Setup Inputs for Case 1
    if has_signal(dut, 'num_nodes'):
        dut.num_nodes.value = 5  # N=5
        dut.num_req_nodes.value = 5 # Nodes 0,1,2,3,4 are required
        dut.req_nodes_mask.value = 0b11111
        
        # Hardcode distances in matrix (8x8 flattened)
        # Initialize with INF (16'hFFFF)
        # We will manually construct the valid distances for the graph
        dist = [[65535]*8 for _ in range(8)]
        for i in range(8): dist[i][i] = 0
        
        # Edges
        dist[0][1] = dist[1][0] = 1000
        dist[1][2] = dist[2][1] = 1000
        dist[3][4] = dist[4][3] = 500
        dist[0][3] = dist[3][0] = 300
        dist[2][4] = dist[4][2] = 300
        
        # Floyd-Warshall Update (Simple logic for 5 nodes)
        for k in range(5):
            for i in range(5):
                for j in range(5):
                    if dist[i][k] + dist[k][j] < dist[i][j]:
                        dist[i][j] = dist[i][k] + dist[k][j]

        # Write to dut dist_matrix
        for i in range(8):
            for j in range(8):
                idx = i * 8 + j
                # Check if signal exists, if not skip (for robustness)
                if has_signal(dut, f'dist_matrix_{idx}'):
                    getattr(dut, f'dist_matrix_{idx}').value = clamp_to_width(dist[i][j], 16)
                elif has_signal(dut, 'dist_matrix') and hasattr(dut.dist_matrix, '__iter__'):
                     dut.dist_matrix[idx].value = clamp_to_width(dist[i][j], 16)

        # Write Required Nodes List
        req_nodes = [0, 1, 2, 3, 4]
        for i in range(len(req_nodes)):
            if has_signal(dut, f'req_node_list_{i}'):
                getattr(dut, f'req_node_list_{i}').value = req_nodes[i]
            elif has_signal(dut, 'req_node_list'):
                 dut.req_node_list[i].value = req_nodes[i]

        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.min_cost.value):
            raise TestFailure("Result signal undefined")
            
        result = int(dut.min_cost.value)
        expected = 3100
        
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test Case 1 Passed: Result {result}")
    else:
        # Combinational check (if not sequential)
        # For simplicity, assume sequential for this problem type
        raise TestFailure("Design appears to be missing sequential interface signals (clk, rst_n)")
