import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_N = 16
CLK_NS = 10
MAX_CYCLES = 2000

# Helper functions

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

def clamp_to_width(v, bits):
    if v < 0: v = 0
    max_val = (1 << bits) - 1
    return min(v, max_val)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_adj_matrix(adj_list, n=16):
    """Pack adjacency matrix into a 256-bit integer."""
    packed = 0
    for i in range(n):
        for j in range(n):
            if i < len(adj_list) and j < len(adj_list[i]):
                if adj_list[i][j]:
                    bit_pos = i * 16 + j
                    packed |= (1 << bit_pos)
    return packed

def extract_cycle(packed_cycle, length, node_width=5):
    """Extract node IDs from packed cycle vector."""
    nodes = []
    for i in range(length):
        shift = i * node_width
        node_id = (packed_cycle >> shift) & ((1 << node_width) - 1)
        nodes.append(node_id)
    return nodes

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dependency_cycle(dut):
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test Case 1: Self-loop (Sample 1 scaled)
    # Node 2 imports itself (c -> c)
    # n=3, edges: 2->2
    n1 = 3
    adj1 = [[0]*16 for _ in range(16)]
    adj1[2][2] = 1  # Self-loop
    packed1 = pack_adj_matrix(adj1, n1)
    
    dut.n.value = n1
    dut.adj_matrix.value = packed1
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done = False
        for _ in range(500):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure("Test 1: Timeout waiting for done")
        
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            cycle_len = int(dut.cycle_length.value)
            if cycle_len != 1:
                raise TestFailure(f"Test 1: Expected cycle length 1, got {cycle_len}")
            packed_cycle = int(dut.cycle_nodes.value)
            nodes = extract_cycle(packed_cycle, cycle_len)
            if nodes != [2]:
                raise TestFailure(f"Test 1: Expected cycle [2], got {nodes}")
            cocotb.log.info("Test 1 PASSED: Self-loop found")
        else:
            raise TestFailure("Test 1: Expected cycle found, but result_valid was 0")
    else:
        await Timer(100, units='ns')
        # For comb logic, just check result directly
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
             cocotb.log.info("Test 1 Combinational: Self-loop detected")

    # Test Case 2: No cycle (Sample 2 scaled)
    # 1->2, 2->3, 3->4 (acyclic)
    n2 = 4
    adj2 = [[0]*16 for _ in range(16)]
    adj2[1][2] = 1
    adj2[2][3] = 1
    adj2[3][4] = 1
    packed2 = pack_adj_matrix(adj2, n2)
    
    dut.n.value = n2
    dut.adj_matrix.value = packed2
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done = False
        for _ in range(500):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure("Test 2: Timeout waiting for done")
        
        if is_value_defined(dut.ship_it.value) and int(dut.ship_it.value) == 1:
            cocotb.log.info("Test 2 PASSED: No cycle found (SHIP IT)")
        else:
            raise TestFailure("Test 2: Expected ship_it=1")
    else:
        await Timer(100, units='ns')

    # Test Case 3: 3-node cycle (Sample 3 scaled)
    # 0->1, 1->2, 2->0
    n3 = 3
    adj3 = [[0]*16 for _ in range(16)]
    adj3[0][1] = 1
    adj3[1][2] = 1
    adj3[2][0] = 1
    packed3 = pack_adj_matrix(adj3, n3)
    
    dut.n.value = n3
    dut.adj_matrix.value = packed3
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done = False
        for _ in range(500):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure("Test 3: Timeout waiting for done")
        
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            cycle_len = int(dut.cycle_length.value)
            if cycle_len != 3:
                raise TestFailure(f"Test 3: Expected cycle length 3, got {cycle_len}")
            packed_cycle = int(dut.cycle_nodes.value)
            nodes = extract_cycle(packed_cycle, cycle_len)
            # Cycle can start at any node, check if it's a valid 3-cycle
            # Valid sets: {0,1,2} in order
            valid_cycle = (nodes == [0,1,2] or nodes == [1,2,0] or nodes == [2,0,1])
            if not valid_cycle:
                raise TestFailure(f"Test 3: Invalid 3-cycle order: {nodes}")
            cocotb.log.info(f"Test 3 PASSED: Cycle {nodes} found")
        else:
            raise TestFailure("Test 3: Expected cycle found")
    else:
        await Timer(100, units='ns')
