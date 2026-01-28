import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_NODES = 16
MAX_EDGES = 32
CLK_NS = 10
MAX_CYCLES = 1000
MOD = 1000000009

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

async def wait_for_done(dut, max_cycles=1000):
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

# Helper to compute expected result (Python reference)
def compute_expected(node_count, edge_count, edges):
    # Build incidence matrix A[node_count][edge_count] over GF(2)
    # Each row i: XOR of edges incident to node i = (degree % 2)
    # But we want to make all degrees even, so target is 0 for all
    # Actually: sum of incident edges must equal current odd degree parity
    # For feasibility, we need current degrees
    if edge_count == 0:
        return 1 if all(d % 2 == 0 for d in [0]*node_count) else 0
    
    # Build incidence matrix
    A = [[0] * edge_count for _ in range(node_count)]
    for i, (a, b) in enumerate(edges):
        if a < node_count:
            A[a][i] = 1
        if b < node_count:
            A[b][i] = 1
    
    # Compute rank using Gaussian elimination over GF(2)
    rank = 0
    row = 0
    for col in range(edge_count):
        if row >= node_count:
            break
        # Find pivot
        pivot = -1
        for r in range(row, node_count):
            if A[r][col] == 1:
                pivot = r
                break
        if pivot == -1:
            continue
        # Swap rows
        A[row], A[pivot] = A[pivot], A[row]
        # Eliminate
        for r in range(node_count):
            if r != row and A[r][col] == 1:
                for c in range(col, edge_count):
                    A[r][c] ^= A[row][c]
        row += 1
        rank += 1
    
    # Number of free variables = edge_count - rank
    free_vars = edge_count - rank
    if free_vars < 0:
        return 0
    
    # Compute 2^free_vars mod MOD
    result = pow(2, free_vars, MOD)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_evenland(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        # (node_count, edge_count, edges, expected)
        (4, 5, [(0,1), (0,2), (0,3), (1,2), (1,3)], 4),  # From sample (1-indexed to 0-indexed)
        (2, 1, [(0,1)], 1),
        (3, 3, [(0,1), (1,2), (0,2)], 2),  # Triangle: 2^1 = 2
        (1, 0, [], 1),  # Single node, no edges
    ]
    
    passed = failed = 0
    
    for i, (node_count, edge_count, edges, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={node_count}, M={edge_count}")
        try:
            # Set inputs
            if has_signal(dut, 'node_count'):
                dut.node_count.value = clamp_to_width(node_count, 4)
            if has_signal(dut, 'edge_count'):
                dut.edge_count.value = clamp_to_width(edge_count, 6)
            
            # Set edges
            for e_idx in range(min(edge_count, 32)):
                a, b = edges[e_idx]
                if has_signal(dut, f'edge_a_{e_idx}'):
                    getattr(dut, f'edge_a_{e_idx}').value = clamp_to_width(a, 4)
                    getattr(dut, f'edge_b_{e_idx}').value = clamp_to_width(b, 4)
            
            # Set unused edges to 0
            for e_idx in range(edge_count, 32):
                if has_signal(dut, f'edge_a_{e_idx}'):
                    getattr(dut, f'edge_a_{e_idx}').value = 0
                    getattr(dut, f'edge_b_{e_idx}').value = 0
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            cocotb.log.info(f"PASS: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
