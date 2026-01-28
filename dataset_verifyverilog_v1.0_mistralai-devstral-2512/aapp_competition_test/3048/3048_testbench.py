import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

# Build adjacency matrix for up to 16 nodes
def build_adjacency(edges, n):
    adj = [[0]*16 for _ in range(16)]
    for u, v in edges:
        if 1 <= u <= n and 1 <= v <= n:
            adj[u-1][v-1] = 1
            adj[v-1][u-1] = 1
    return adj

def compute_expected(edges, n):
    # Compute degrees and sum deg*(deg-1)
    deg = [0]*n
    for u, v in edges:
        deg[u-1] += 1
        deg[v-1] += 1
    total = 0
    for d in deg:
        total += d * (d - 1)
    return total

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_optimal_paths(dut):
    CLK_NS = 10
    DATA_WIDTH = 1
    MATRIX_SIZE = 16
    MAX_N = 16
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        # Input from examples, but adapted for N=16 max
        ([ (1,2), (1,3) ], 3, 2),
        ([ (2,1), (1,5), (3,1), (4,3) ], 5, 8),
        ([ (1,2), (2,3), (2,4), (1,5), (3,6), (2,7), (7,8), (5,9), (5,10) ], 10, 24),
        ([ (1,2), (2,3), (3,4), (4,5), (5,6), (6,1), (2,1) ], 8, 12),
        ([ (1,2), (2,3), (3,1) ], 3, 6),  # triangle but tree? No, tree input ensures no cycles. This is a counter for general graph but input is tree.
        ([ (1,2) ], 2, 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (edges, n, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={n}, edges={edges}")
        try:
            adj = build_adjacency(edges, n)
            
            # Write adjacency matrix to DUT
            # Assuming interface: adj[i*16 + j] or adj[i][j]
            # Iterate over all 16x16 bits
            for row in range(16):
                for col in range(16):
                    idx = row * 16 + col
                    if has_signal(dut, f'adj_{row}_{col}'):
                        getattr(dut, f'adj_{row}_{col}').value = adj[row][col]
                    elif has_signal(dut, 'adj'):
                        # Packed or array of arrays
                        dut.adj[row][col].value = adj[row][col]
                    else:
                        # Assume flat array
                        dut.adj[idx].value = adj[row][col]
            
            # Start signal
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
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")