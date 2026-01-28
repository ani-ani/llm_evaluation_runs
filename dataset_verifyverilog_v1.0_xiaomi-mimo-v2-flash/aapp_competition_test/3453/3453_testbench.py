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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Scaled constants for N=8
MAX_NODES = 8
MAX_EDGES = 16
DATA_WIDTH = 8
EDGE_WIDTH = 24  # src[3:0], dst[3:0], len[7:0]
RESULT_WIDTH = 16
MOD_VAL = 1000000007
CLK_NS = 10

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_edges(dut, edges, edge_valid):
    """Write edges to packed array, ensure width clamping"""
    for i in range(MAX_EDGES):
        if i < len(edges):
            src, dst, l = edges[i]
            packed = (src << 16) | (dst << 8) | l
            dut.edges[i].value = clamp_to_width(packed, EDGE_WIDTH)
            dut.edge_valid[i].value = 1
        else:
            dut.edges[i].value = 0
            dut.edge_valid[i].value = 0

async def read_results(dut):
    """Read packed results from output array"""
    results = []
    for i in range(MAX_NODES):
        if has_signal(dut, f'result_{i}'):
            val = getattr(dut, f'result_{i}').value
            results.append(safe_int(val, 0))
        elif hasattr(dut.result, '__getitem__'):
            results.append(safe_int(dut.result[i].value, 0))
        else:
            results.append(0)
    return results

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_cactus_distances(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: just wait
        await Timer(100, units='ns')
    
    # Test case 1: Sample from problem (scaled to 8 nodes)
    # Original: 5 nodes, 5 edges. Scale to 8 nodes (add dummy nodes 6,7 with no edges)
    # But we can just use first 5 nodes as 0-4, edges as given
    # Edges: (0-1:3), (0-3:8), (1-2:12), (2-4:4), (3-4:2)
    edges1 = [
        (0, 1, 3),
        (0, 3, 8),
        (1, 2, 12),
        (2, 4, 4),
        (3, 4, 2)
    ]
    edge_valid1 = [1] * len(edges1) + [0] * (MAX_EDGES - len(edges1))
    node_count1 = 5  # 0-4
    expected1 = [35, 39, 36, 27, 29, 0, 0, 0]  # Padded to 8 nodes
    
    # Test case 2: Simple tree
    edges2 = [
        (0, 1, 2),
        (1, 2, 3),
        (2, 3, 4)
    ]
    edge_valid2 = [1] * len(edges2) + [0] * (MAX_EDGES - len(edges2))
    node_count2 = 4
    # Manual compute: dist matrix, then sums
    # 0:0,1:2,2:5,3:9 -> sum=16
    # 1:2,0,3,7 -> sum=12
    # 2:5,3,0,4 -> sum=12
    # 3:9,7,4,0 -> sum=20
    expected2 = [16, 12, 12, 20, 0, 0, 0, 0]
    
    test_cases = [
        (node_count1, edges1, edge_valid1, expected1, "Sample scaled"),
        (node_count2, edges2, edge_valid2, expected2, "Simple tree")
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, (n, edges, ev, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {tc_idx+1}: {desc} (N={n})")
        try:
            # Write inputs
            await write_edges(dut, edges, ev)
            if is_seq:
                dut.node_count.value = n
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational module
                dut.node_count.value = n
                await Timer(5000, units='ns')  # Allow calc time
            
            # Read results
            results = await read_results(dut)
            cocotb.log.info(f"Results: {results[:n]}")
            
            # Compare (only for active nodes)
            for i in range(n):
                if i >= len(results):
                    raise TestFailure(f"Result {i} not read")
                if results[i] != expected[i]:
                    raise TestFailure(f"Node {i}: Expected {expected[i]}, got {results[i]}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")