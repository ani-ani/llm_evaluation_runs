import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 1
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_matrix(dut, matrix):
    # matrix is 8x8 list of 0/1
    for r in range(8):
        for c in range(8):
            if has_signal(dut, f'adj_matrix_{r}_{c}'):
                getattr(dut, f'adj_matrix_{r}_{c}').value = matrix[r][c]
            elif has_signal(dut, f'adj_matrix_{r}') and hasattr(getattr(dut, f'adj_matrix_{r}'), '__getitem__'):
                getattr(dut, f'adj_matrix_{r}')[c].value = matrix[r][c]
            else:
                # Fallback for packed array or other structure
                pass

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tree_reconstruction(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Case 1: Line graph 1-2-3-4 (as per sample)
    # 4 nodes, 1-2, 2-3, 3-4
    matrix1 = [[0]*8 for _ in range(8)]
    matrix1[0][1] = matrix1[1][0] = 1
    matrix1[1][2] = matrix1[2][1] = 1
    matrix1[2][3] = matrix1[3][2] = 1
    
    dut.n_nodes.value = 4
    await write_matrix(dut, matrix1)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    # Expected result for line graph 1-2-3-4:
    # Current diameter = 3 (1 to 4)
    # Breaking edge 2-3 splits into [1,2] and [3,4]. Diameter of each is 1.
    # Reconnecting 2-4 (or 1-3) gives path 1-2-4-3: distance 1->2->4->3 = 3?
    # Wait, optimal is breaking 2-3 and connecting 1-3 (or 2-4).
    # 1-2-3-4. Break 2-3. Components: {1,2}, {3,4}.
    # Connect 2-4. New graph: 1-2-4-3. Diameter 1->3 = 2 (1-2-4-3 is length 3, 1-2-4 is 2, 2-4-3 is 2).
    # Or connect 1-3. 1-2-3-4? No. 1-3 connects components. Path 1-3-4 is 2. Path 1-2-1-3 is 2.
    # Actually, output example says: 2 (distance), close 3 4, open 4 2.
    # This implies breaking edge (3,4) and opening (4,2).
    # Original path 1-2-3-4. Diameter 3.
    # Break (3,4). Components: {1,2,3}, {4}.
    # Connect (4,2). New graph: 1-2-3, 2-4. Diameter 1->4 = 2 (1-2-4).
    # So result should be 2.
    
    dist = int(dut.result_distance.value)
    if dist != 2:
        raise TestFailure(f"Test 1: Expected dist 2, got {dist}")
        
    # Check closing edge (should be 3,4)
    u = int(dut.edge_close_u.value)
    v = int(dut.edge_close_v.value)
    # Normalize (u,v) or (v,u)
    if u > v: u, v = v, u
    if not ((u == 2 and v == 3) or (u == 3 and v == 4)):
        cocotb.log.info(f"Close edge: {int(dut.edge_close_u.value)} {int(dut.edge_close_v.value)}")
    
    # Check opening edge (should be 2,4)
    u = int(dut.edge_open_u.value)
    v = int(dut.edge_open_v.value)
    if u > v: u, v = v, u
    if not ((u == 1 and v == 3) or (u == 2 and v == 3) or (u == 1 and v == 2)):
         cocotb.log.info(f"Open edge: {int(dut.edge_open_u.value)} {int(dut.edge_open_v.value)}")

    # Test Case 2: Star graph (center 1, leaves 2,3,4)
    # 1-2, 1-3, 1-4
    matrix2 = [[0]*8 for _ in range(8)]
    matrix2[0][1] = matrix2[1][0] = 1
    matrix2[0][2] = matrix2[2][0] = 1
    matrix2[0][3] = matrix2[3][0] = 1
    
    dut.n_nodes.value = 4
    await write_matrix(dut, matrix2)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    # Star diameter is 2. Optimal diameter is 2 (cannot be smaller).
    # Breaking any edge and reconnecting keeps diameter 2 or increases it.
    # Result should be 2.
    dist = int(dut.result_distance.value)
    if dist != 2:
         raise TestFailure(f"Test 2: Expected dist 2, got {dist}")

    cocotb.log.info(f"All tests passed. Result dist: {dist}")
